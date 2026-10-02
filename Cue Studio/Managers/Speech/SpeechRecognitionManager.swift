//
//  SpeechRecognitionManager.swift
//  Cue Studio
//

import AVFAudio
import os
import Speech
import Synchronization

/// Voice follow's ears: on-device transcription with the Speech framework (`SpeechAnalyzer`), in the
/// language Voice Following listens for (Settings › Language & Region, or the script's). Nothing
/// leaves the device and nothing is paid per use.
///
/// `SpeechTranscriber` recognizes every language it supports here, exactly as it always has;
/// `DictationTranscriber`, from the same framework, takes the languages (and devices) it doesn't.
/// The first time a language is used its model may need a download, of that language only, and
/// the prompter says so while it runs; until it's ready, Voice follow falls back to the microphone
/// level. The model is kept only while in use: keeping it loaded after a stop (`lingering`) was
/// measured on an iPhone 18 Pro Max and restarted no faster (the system keeps it warm), so the
/// original retention stays.
@MainActor
@Observable
final class SpeechRecognitionManager: SpeechTranscribing {
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    /// Bumped by every start and stop, so a start still waiting on a download backs out when
    /// something newer happened meanwhile.
    private var generation = 0
    /// Bumped by `discardHeard`; the transcript being read starts over when it sees a new one.
    private let transcriptEpoch = Epoch()

    private let resolver: SpeechLocaleResolver
    private let use: SpeechUse

    init(resolver: SpeechLocaleResolver = SpeechLocaleResolver(), use: SpeechUse = .following) {
        self.resolver = resolver
        self.use = use
    }

    func start(
        script: String, language: SpeechLanguageRequest, preparation: @escaping (SpeechPreparation) -> Void
    ) async -> SpeechStartResult {
        stop()
        let current = generation
        preparation(.preparing)
        let route: SpeechRoute
        switch await resolver.resolve(language, scriptText: script) {
        case .success(let resolved): route = resolved
        case .failure(let reason): return current == generation ? .unavailable(reason) : .cancelled
        }
        let module = Self.module(for: route)
        let modules: [any SpeechModule] = [module.speechModule]
        do {
            await Self.reserve(route.locale)
            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                guard current == generation else { return .cancelled }
                guard await download(request, of: route.language, preparation: preparation) else {
                    return current == generation ? .unavailable(.needsDownload(route.language)) : .cancelled
                }
                guard current == generation else { return .cancelled }
                preparation(.preparing)
            }
            let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules)
            guard current == generation else { return .cancelled }
            // Installed but unable to take audio: the model can't run here (the simulator).
            guard let format else { return .unavailable(.noRecognition) }
            let analyzer = SpeechAnalyzer(modules: modules, options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .whileInUse))
            let context = AnalysisContext()
            context.contextualStrings[.general] = Self.vocabulary(in: script)
            try? await analyzer.setContext(context)
            try await analyzer.prepareToAnalyze(in: format)
            let (inputs, input) = AsyncStream.makeStream(of: AnalyzerInput.self)
            try await analyzer.start(inputSequence: inputs)
            guard current == generation else {
                input.finish()
                await analyzer.cancelAndFinishNow()
                return .cancelled
            }
            self.analyzer = analyzer
            self.input = input
            let transcripts = listen(to: module)
            let feed = AudioFeed(analyzerFormat: format, input: input)
            return .listening(SpeechTranscription(audio: { feed.append($0) }, transcripts: transcripts), route)
        } catch {
            #if DEBUG
            Logger(subsystem: "studio.cue", category: "VoiceFollowing").error("Recognition couldn't start: \(error, privacy: .public)")
            #endif
            return current == generation ? .unavailable(.couldNotStart) : .cancelled
        }
    }

    func stop() {
        generation += 1
        input?.finish()
        input = nil
        resultsTask?.cancel()
        resultsTask = nil
        if let analyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
        analyzer = nil
    }

    /// Stops listening and lets the recognizer say what it heard in the last words before it
    /// closes, so the transcript ends up whole (the words still being worked out are finalized).
    /// Returns when the transcript stream has ended. Dictation uses it; Voice Following just stops.
    func finish() async {
        generation += 1
        input?.finish()
        input = nil
        let results = resultsTask
        resultsTask = nil
        guard let analyzer else {
            results?.cancel()
            return
        }
        self.analyzer = nil
        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            results?.cancel()
            await analyzer.cancelAndFinishNow()
        }
        await results?.value
    }

    func discardHeard() {
        transcriptEpoch.advance()
    }

    // MARK: - Availability

    /// Whether Voice Following can follow the words in `language` here, and whether its model is
    /// already on the device.
    func availability(of language: CueLanguage) async -> VoiceFollowingAvailability {
        guard case .success(let route) = await resolver.resolve(.language(language)) else { return .unavailable }
        let modules = [Self.module(for: route).speechModule]
        switch await AssetInventory.status(forModules: modules) {
        case .installed:
            // Some devices list a model they can't run (the simulator): no audio format for it.
            return await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) == nil ? .unavailable : .ready
        case .unsupported: return .unavailable
        default: return .downloadsOnFirstUse
        }
    }

    // MARK: - Recognizers

    /// The recognizer for a route, with Voice Following's options: words as they're being said
    /// (volatile), finalized quickly.
    private enum Module {
        case transcriber(SpeechTranscriber)
        case dictation(DictationTranscriber)

        var speechModule: any SpeechModule {
            switch self {
            case .transcriber(let transcriber): transcriber
            case .dictation(let dictation): dictation
            }
        }
    }

    private static func module(for route: SpeechRoute) -> Module {
        switch route.engine {
        case .transcriber:
            .transcriber(SpeechTranscriber(
                locale: route.locale,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults, .fastResults],
                attributeOptions: []
            ))
        case .dictation:
            .dictation(DictationTranscriber(
                locale: route.locale,
                contentHints: [],
                transcriptionOptions: [],
                reportingOptions: [.volatileResults, .frequentFinalization],
                attributeOptions: []
            ))
        }
    }

    /// Finalized text plus the words still being recognized, as one running transcript.
    private func listen(to module: Module) -> AsyncStream<String> {
        let (transcripts, output) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
        let use = use
        let transcriptEpoch = transcriptEpoch
        resultsTask = Task {
            var finalized = ""
            var epoch = transcriptEpoch.current
            func joined(_ text: String) -> String {
                finalized + use.separator(after: finalized, before: text) + text
            }
            func heard(_ text: String, isFinal: Bool) {
                if transcriptEpoch.current != epoch {
                    epoch = transcriptEpoch.current
                    finalized = ""
                }
                if isFinal {
                    finalized = joined(text)
                    if let limit = use.transcriptLimit { finalized = String(finalized.suffix(limit)) }
                    output.yield(finalized)
                } else {
                    output.yield(joined(text))
                }
            }
            do {
                switch module {
                case .transcriber(let transcriber):
                    for try await result in transcriber.results {
                        heard(String(result.text.characters), isFinal: result.isFinal)
                    }
                case .dictation(let dictation):
                    for try await result in dictation.results {
                        heard(String(result.text.characters), isFinal: result.isFinal)
                    }
                }
            } catch {
                // Cancelled or failed: the stream ends, and Voice follow falls back to the level.
                #if DEBUG
                Logger(subsystem: "studio.cue", category: "VoiceFollowing").error("Recognition ended: \(error, privacy: .public)")
                #endif
            }
            output.finish()
        }
        return transcripts
    }

    // MARK: - Assets

    /// Downloads the language's model, telling `preparation` how far along it is. False when the
    /// download failed (no internet, most often).
    private func download(_ request: AssetInstallationRequest, of language: CueLanguage?, preparation: @escaping (SpeechPreparation) -> Void) async -> Bool {
        preparation(.downloading(language, progress: nil))
        let watcher = Task {
            // The system's download reports its own progress; read it while it runs.
            while !Task.isCancelled {
                preparation(.downloading(language, progress: request.progress.fractionCompleted))
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        defer { watcher.cancel() }
        do {
            try await request.downloadAndInstall()
            return true
        } catch {
            return false
        }
    }

    /// Keeps the language's model on the device. The system holds a few reserved languages at a
    /// time; when they're taken, the oldest other one makes room, so a new language still works.
    private static func reserve(_ locale: Locale) async {
        let reserved = await AssetInventory.reservedLocales
        guard !reserved.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else { return }
        if (try? await AssetInventory.reserve(locale: locale)) == true { return }
        if reserved.count >= AssetInventory.maximumReservedLocales, let oldest = reserved.first {
            await AssetInventory.release(reservedLocale: oldest)
            _ = try? await AssetInventory.reserve(locale: locale)
        }
    }

    /// Names, brands and numbers a general model may not expect, as recognition hints. Text
    /// written without spaces has no word boundaries to cut a name out by, so it gives none.
    private static func vocabulary(in script: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for word in CueParser.stripCues(script).split(whereSeparator: \.isWhitespace) {
            let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
            guard trimmed.count >= 3, !WordSegmenter.containsUnspacedScript(trimmed),
                  trimmed.first?.isUppercase == true || trimmed.contains(where: \.isNumber),
                  seen.insert(trimmed.lowercased()).inserted else { continue }
            result.append(trimmed)
            if result.count == 100 { break }
        }
        return result
    }

    /// A counter the transcript's task reads off the main actor.
    private nonisolated final class Epoch: Sendable {
        private let value = Mutex(0)
        var current: Int { value.withLock { $0 } }
        func advance() { value.withLock { $0 += 1 } }
    }

    // MARK: - Audio

    /// Converts microphone buffers to the analyzer's format on the audio thread. A new converter
    /// takes over when the buffers change format (the camera's audio and Studio's meter differ), so
    /// one recognition runs across a switch between Selfie and Studio. The inputs carry no start
    /// time of their own: the analyzer places them one after the other, so a new converter never
    /// sends it back in time (`AnalyzerInputConverter` stamps each buffer from its own clock, which
    /// starts at zero again, and the analyzer ends the recognition: "timestamp overlaps or precedes").
    private nonisolated final class AudioFeed: Sendable {
        private let lock = NSLock()
        // Only touched while holding `lock`. A `Mutex` can't hold them: converting ties each
        // caller's buffer to the converter, which region checking rejects.
        private nonisolated(unsafe) var converter: AVAudioConverter?
        private nonisolated(unsafe) var sourceFormat: AVAudioFormat?
        private let analyzerFormat: AVAudioFormat
        private let input: AsyncStream<AnalyzerInput>.Continuation

        init(analyzerFormat: AVAudioFormat, input: AsyncStream<AnalyzerInput>.Continuation) {
            self.analyzerFormat = analyzerFormat
            self.input = input
        }

        func append(_ buffer: AVAudioPCMBuffer) {
            let converted = lock.withLock { convert(buffer) }
            if let converted {
                input.yield(AnalyzerInput(buffer: converted))
            }
        }

        /// Called with `lock` held. Nil when the buffer can't be converted (it is skipped).
        private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
            let format = buffer.format
            if converter == nil || sourceFormat != format {
                converter = AVAudioConverter(from: format, to: analyzerFormat)
                sourceFormat = format
            }
            guard let converter else { return nil }
            let ratio = analyzerFormat.sampleRate / max(1, format.sampleRate)
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
            guard let output = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return nil }
            nonisolated(unsafe) let source = buffer
            nonisolated(unsafe) var supplied = false
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, inputStatus in
                if supplied {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                supplied = true
                inputStatus.pointee = .haveData
                return source
            }
            guard status != .error, error == nil, output.frameLength > 0 else { return nil }
            return output
        }
    }
}
