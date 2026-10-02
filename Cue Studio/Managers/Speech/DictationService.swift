//
//  DictationService.swift
//  Cue Studio
//

import AVFAudio
import Foundation

/// Speaking an idea into a text field (the empty Scripts screen's card): the microphone and the
/// on-device recognizer (`SpeechRecognitionManager`, Speech framework) put together, with nothing
/// else. It writes no audio file, sends nothing anywhere and never writes the script: the words go
/// to whoever started it, as they are heard, and generating stays a separate step the creator takes.
///
/// It has its own microphone and recognizer, so it never shares handlers with the prompter; and it
/// lets go of both the moment it stops, is interrupted, or the creator leaves the screen.
///
/// The microphone is asked for only when the creator taps it. A language the device can't
/// recognize is never swapped for another: the creator is told, and typing works as before.
@MainActor
@Observable
final class DictationService {
    private(set) var state: DictationState = .idle
    /// Why the last dictation didn't start or ended on its own; nil once a new one starts or it's dismissed.
    private(set) var notice: DictationNotice?
    /// The voice, 0...1, for the activity indicator.
    private(set) var level = 0.0

    var isActive: Bool { state.isActive }

    @ObservationIgnored private let audio: AudioLevelMetering
    @ObservationIgnored private let speech: SpeechTranscribing
    @ObservationIgnored private let microphone: MicrophoneAccess
    /// How long the last words get to be finalized after a stop before it lets go anyway.
    @ObservationIgnored private let finishTimeout: Duration
    /// How long without audio before the microphone is taken as gone (an unplugged mic, a call),
    /// and how often that is checked.
    @ObservationIgnored private let silenceTimeout: Duration
    @ObservationIgnored private let watchInterval: Duration
    @ObservationIgnored private let clock = ContinuousClock()

    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var transcript = ""
    @ObservationIgnored private var onTranscript: ((String) -> Void)?
    @ObservationIgnored private var lastAudio: ContinuousClock.Instant?
    @ObservationIgnored private var lastLevelUpdate = 0.0
    /// Reads the transcript; it lives through a stop, until the last words are in.
    @ObservationIgnored private var transcriptTask: Task<Void, Never>?
    /// The level, the microphone watch and the finishing; they end with the stop.
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    init(
        audio: AudioLevelMetering, speech: SpeechTranscribing, microphone: MicrophoneAccess = MicrophoneAccess(),
        finishTimeout: Duration = .seconds(3), silenceTimeout: Duration = .seconds(4), watchInterval: Duration = .seconds(1)
    ) {
        self.audio = audio
        self.speech = speech
        self.microphone = microphone
        self.finishTimeout = finishTimeout
        self.silenceTimeout = silenceTimeout
        self.watchInterval = watchInterval
        observeInterruptions()
    }

    // MARK: - Starting

    /// Starts listening in `language`; `onTranscript` gets everything heard so far, again and
    /// again as it grows (the last words may be rewritten as they firm up). Returns once it is
    /// listening, or once it knows it can't (`state` is idle then and `notice` says why).
    func start(language: SpeechLanguageRequest, onTranscript: @escaping (String) -> Void) async {
        guard state == .idle else { return }
        generation += 1
        let current = generation
        notice = nil
        transcript = ""
        level = 0
        self.onTranscript = onTranscript
        if microphone.isDenied() {
            fail(.microphoneDenied)
            return
        }
        state = .preparing(nil)
        guard await microphone.request() else {
            if current == generation { fail(.microphoneDenied) }
            return
        }
        guard current == generation else { return }
        let result = await speech.start(script: "", language: language) { [weak self] preparation in
            guard let self, self.generation == current, case .preparing = self.state else { return }
            self.state = .preparing(preparation)
        }
        guard current == generation else { return }
        switch result {
        case .listening(let transcription, _):
            await listen(to: transcription, generation: current)
        case .unavailable(let reason):
            fail(.unavailable(reason))
        case .cancelled:
            fail(.unavailable(.couldNotStart))
        }
    }

    private func listen(to transcription: SpeechTranscription, generation current: Int) async {
        let (levels, levelInput) = AsyncStream.makeStream(of: AudioLevelSample.self, bufferingPolicy: .bufferingNewest(8))
        audio.setAudioHandler(transcription.audio)
        audio.setLevelHandler { levelInput.yield($0) }
        guard await audio.startMetering() else {
            guard current == generation else { return }
            release()
            fail(microphone.isDenied() ? .microphoneDenied : .unavailable(.couldNotStart))
            return
        }
        guard current == generation else {
            release()
            return
        }
        state = .listening
        lastAudio = clock.now
        lastLevelUpdate = 0
        tasks.append(Task { [weak self] in
            for await sample in levels { self?.heard(sample, generation: current) }
        })
        transcriptTask = Task { [weak self] in
            guard let self else { return }
            for await text in transcription.transcripts {
                guard self.generation == current else { return }
                self.heard(text)
            }
            self.recognitionEnded(generation: current)
        }
        tasks.append(Task { [weak self] in
            await self?.watchMicrophone(generation: current)
        })
    }

    // MARK: - Stopping

    /// The creator stopped: the microphone closes now and the recognizer finalizes the last
    /// words, so none is lost; then the state goes back to idle. While it only prepares, this cancels.
    func stop() {
        switch state {
        case .preparing:
            cancel()
        case .listening:
            state = .finishing
            level = 0
            let current = generation
            audio.stopMetering()
            audio.setAudioHandler(nil)
            audio.setLevelHandler(nil)
            tasks.forEach { $0.cancel() }
            tasks = []
            // The transcript stream ends once the last words are in, and `recognitionEnded` completes
            // the stop. If the recognizer takes too long, it's closed as it is.
            let speech = speech
            let timeout = finishTimeout
            tasks.append(Task { await speech.finish() })
            tasks.append(Task { [weak self] in
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled, let self, self.generation == current, self.state == .finishing else { return }
                self.speech.stop()
            })
        default:
            break
        }
    }

    /// Lets go now, whatever it was doing: leaving the screen, a sheet or the camera opening. The
    /// words already written stay.
    func cancel() {
        guard state != .idle else { return }
        generation += 1
        release()
        state = .idle
        onTranscript = nil
    }

    /// The system or the app's own state took the microphone away. The words heard so far stay,
    /// and the creator is told once, so it never looks like a bug.
    func interrupt() {
        guard state != .idle else { return }
        let wasListening = state == .listening || state == .finishing
        cancel()
        if wasListening { notice = .interrupted }
    }

    func dismissNotice() {
        notice = nil
    }

    // MARK: - Hearing

    private func heard(_ text: String) {
        guard state == .listening || state == .finishing else { return }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard words != transcript else { return }
        transcript = words
        onTranscript?(words)
    }

    /// The voice's level, a few times a second at most: the indicator doesn't need more, and the
    /// text must not be redrawn faster than it can be read.
    private func heard(_ sample: AudioLevelSample, generation current: Int) {
        guard generation == current, state == .listening else { return }
        lastAudio = clock.now
        guard sample.time - lastLevelUpdate >= 0.05 else { return }
        lastLevelUpdate = sample.time
        let next = Self.normalized(sample.level)
        level = max(next, level * 0.7)
    }

    /// -55 dBFS (a quiet room) to -15 dBFS (close, loud speech) as 0...1.
    nonisolated static func normalized(_ decibels: Float) -> Double {
        min(1, max(0, Double(decibels + 55) / 40))
    }

    /// The transcript stream ended: after a stop, that is the last of the words (done); on its own,
    /// the recognizer gave up, and the creator is told.
    private func recognitionEnded(generation current: Int) {
        guard generation == current else { return }
        switch state {
        case .finishing:
            let nothing = transcript.isEmpty
            release()
            generation += 1
            state = .idle
            onTranscript = nil
            if nothing { notice = .nothingHeard }
        case .listening:
            interrupt()
        default:
            break
        }
    }

    /// An unplugged mic or a call can stop the audio without a word. No audio for a few seconds
    /// while listening counts as an interruption.
    private func watchMicrophone(generation current: Int) async {
        while !Task.isCancelled, generation == current {
            try? await Task.sleep(for: watchInterval)
            guard !Task.isCancelled, generation == current, state == .listening, let lastAudio else { continue }
            if lastAudio.duration(to: clock.now) > silenceTimeout {
                interrupt()
                return
            }
        }
    }

    // MARK: - Letting go

    private func finish(with notice: DictationNotice) {
        self.notice = notice
        state = .idle
        onTranscript = nil
        level = 0
    }

    /// Closes the microphone and the recognizer and drops every task.
    private func release() {
        tasks.forEach { $0.cancel() }
        tasks = []
        transcriptTask?.cancel()
        transcriptTask = nil
        audio.stopMetering()
        audio.setAudioHandler(nil)
        audio.setLevelHandler(nil)
        speech.stop()
        level = 0
        lastAudio = nil
    }

    private func observeInterruptions() {
        let center = NotificationCenter.default
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: nil) { [weak self] notification in
                let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                    .map { $0 == AVAudioSession.InterruptionType.began.rawValue } ?? true
                guard began else { return }
                Task { @MainActor [weak self] in self?.interrupt() }
            })
        }
    }
}
