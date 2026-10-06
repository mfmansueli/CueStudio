//
//  PrompterViewModel+VoiceFollow.swift
//  Cue Studio
//

import Foundation

/// Voice Following: speech recognition keeps the text on the word being read, and the microphone's level lights the
/// indicator and runs the text a little ahead. The state it keeps lives in `PrompterViewModel` (stored properties can't
/// live in an extension).
extension PrompterViewModel {
    func scrollModeChanged() {
        updateVoiceMonitoring()
    }

    /// What the voice indicator and Studio's line say.
    var voiceFollowStatus: VoiceFollowStatus {
        VoiceFollowStatus(followsSpeech: followsSpeech, preparation: speechPreparation)
    }

    /// Speech recognition moves the text to the word being read (see `followSpeech`); the level of
    /// each buffer, as it arrives, lights the indicator, lets the text run a little ahead of the
    /// words (`SpeechLead`) and drives scrolling when recognition isn't available. In Selfie mode
    /// both come from the camera's audio; in Studio mode from a meter of their own.
    func updateVoiceMonitoring() {
        guard session.prompter.scrollMode == .voice, script != nil else {
            stopVoiceMonitoring()
            return
        }
        startSpeechIfNeeded()
        routeSpeechAudio()
        listenForVoice()
    }

    func stopVoiceMonitoring() {
        levelTask?.cancel()
        levelTask = nil
        camera.setLevelHandler(nil)
        audio.setLevelHandler(nil)
        stopFollowingSpeech()
        isVoiceActive = false
        voiceLevel = 0
        speechUnavailable = nil
        speechRestarts = 0
        voiceGate = VoiceFollowGate()
        audio.stopMetering()
    }

    /// Starts recognition for the script in Voice Following's language, unless it already listens
    /// (or gets ready to) for the same text and language.
    func startSpeechIfNeeded() {
        guard session.prompter.scrollMode == .voice, let script else { return }
        let wanted = SpeechSession(text: script.text, language: languages.speechRequest(for: script))
        guard wanted != speechSession else { return }
        stopFollowingSpeech()
        speechSession = wanted
        speechPreparation = .preparing
        voiceMetrics.enabled(at: clock())
        speechTask = Task { [weak self] in
            await self?.followSpeech(wanted)
        }
    }

    /// Listens for the script being read, in the Voice Following language (or the script's), and
    /// keeps the tracker on the next word to read. A language this device can't recognize is never
    /// swapped for another: the text follows the voice level and the creator is told why.
    private func followSpeech(_ wanted: SpeechSession) async {
        let generation = speechGeneration
        let result = await speech.start(script: wanted.text, language: wanted.language) { [weak self] preparation in
            guard let self, self.speechGeneration == generation else { return }
            self.speechPreparation = preparation
            if case .downloading = preparation { self.voiceMetrics.downloading() }
        }
        guard !Task.isCancelled, speechGeneration == generation else { return }
        speechPreparation = nil
        let started: SpeechTranscription
        let language: CueLanguage?
        switch result {
        case .listening(let transcription, let route):
            started = transcription
            language = route.language
            listeningLanguage = route.language
            speechUnavailable = nil
        case .unavailable(let reason):
            speechUnavailable = reason
            if noticedSpeechUnavailable != reason {
                noticedSpeechUnavailable = reason
                toast.show(reason.message)
            }
            return
        case .cancelled:
            return
        }
        transcription = started
        scriptWords = ScriptWords(text: wanted.text, language: language)
        speechTracker = ScriptSpeechTracker(words: scriptWords.tokens, language: language)
        speechLead.initialRate = ReadTime.wordsPerMinute(speed: session.prompter.speed) / 60
        followsSpeech = true
        routeSpeechAudio()
        syncSpeechPosition()
        voiceMetrics.listening(at: clock())
        for await heard in started.transcripts {
            let received = clock()
            if speechTracker.hear(heard) {
                speechRestarts = 0
                voiceMetrics.confirmed(ahead: speechLead.position - Double(speechTracker.position))
                speechLead.confirm(speechTracker.position, at: received)
            }
            voiceMetrics.transcript(heard, receivedAt: received, alignedAt: clock())
        }
        // Recognition ended on its own: fall back to the level. A cancelled task was replaced.
        guard !Task.isCancelled, speechGeneration == generation else { return }
        followsSpeech = false
        transcription = nil
        routeSpeechAudio()
        await restartSpeech(after: generation)
    }

    /// A recognizer that stops by itself (the system took the audio for a moment, a model was
    /// unloaded) is started again, a few times in a row, before the text settles for the level. Every
    /// word it confirms in between starts the count over.
    private func restartSpeech(after generation: Int) async {
        guard speechRestarts < Self.maximumSpeechRestarts else { return }
        speechRestarts += 1
        try? await Task.sleep(for: speechRestartDelay)
        guard !Task.isCancelled, speechGeneration == generation else { return }
        speechSession = nil
        startSpeechIfNeeded()
    }

    private func stopFollowingSpeech() {
        logVoiceMetrics()
        speechTask?.cancel()
        speechTask = nil
        speechSession = nil
        speechGeneration += 1
        transcription = nil
        followsSpeech = false
        listeningLanguage = nil
        speechPreparation = nil
        camera.setAudioHandler(nil)
        audio.setAudioHandler(nil)
        speech.stop()
    }

    /// The camera hears the creator in Selfie; Studio has no camera and listens through a meter of its own.
    private var listensThroughCamera: Bool {
        mode == .selfie
    }

    /// Sends the microphone to recognition: the camera's, or the meter's when there is no camera.
    private func routeSpeechAudio() {
        let handler = transcription?.audio
        camera.setAudioHandler(listensThroughCamera ? handler : nil)
        audio.setAudioHandler(listensThroughCamera ? nil : handler)
    }

    /// Each buffer's level as it arrives, from this mode's microphone. Nothing polls: the
    /// indicator lights within a buffer of the voice.
    private func listenForVoice() {
        levelTask?.cancel()
        let (samples, continuation) = AsyncStream.makeStream(of: AudioLevelSample.self, bufferingPolicy: .bufferingNewest(64))
        let handler: @Sendable (AudioLevelSample) -> Void = { continuation.yield($0) }
        let throughCamera = listensThroughCamera
        camera.setLevelHandler(throughCamera ? handler : nil)
        audio.setLevelHandler(throughCamera ? nil : handler)
        levelTask = Task { [weak self] in
            if !throughCamera {
                _ = await self?.audio.startMetering()
            }
            for await sample in samples {
                self?.hear(sample)
            }
        }
    }

    private func hear(_ sample: AudioLevelSample) {
        let speaking = voiceGate.hear(level: sample.level, at: sample.time, duration: sample.duration)
        let changed = speaking != isVoiceActive
        showVoice(speaking, heardAt: sample.time)
        // The meter jumps with the voice starting or stopping; in between it redraws at a steady pace.
        guard changed || sample.time - levelShownAt >= Self.levelInterval else { return }
        levelShownAt = sample.time
        let level = VoiceFollowGate.normalized(sample.level)
        if level != voiceLevel { voiceLevel = level }
    }

    func showVoice(_ speaking: Bool, heardAt time: TimeInterval) {
        guard speaking != isVoiceActive else { return }
        isVoiceActive = speaking
        voiceMetrics.voice(speaking, heardAt: time, shownAt: clock())
    }

    /// Where the text should be: the next word to read on the guide, run a little ahead while the
    /// creator speaks (`SpeechLead`), never more than a fraction of a line past the last word
    /// recognized, and never onto the end, which only the last word heard reaches.
    var speechTarget: Double? {
        let position = speechTracker.position
        guard let confirmed = scriptWords.offset(
            forWord: position, paragraphFrames: paragraphFrames, lineHeight: lineHeight, endOffset: engine.endOffset
        ) else { return nil }
        guard position < scriptWords.count else { return confirmed }
        let predicted = min(speechLead.position, Double(scriptWords.count - 1))
        guard predicted > Double(position),
              let ahead = scriptWords.offset(
                  forPosition: predicted, paragraphFrames: paragraphFrames, lineHeight: lineHeight, endOffset: engine.endOffset
              ) else { return confirmed }
        let limit = min(confirmed + lineHeight * speechLead.maximumLines, engine.endOffset - 1)
        return max(confirmed, min(ahead, limit))
    }

    /// After a manual scroll, reading picks up from what's on the guide.
    func syncSpeechPosition() {
        guard followsSpeech else { return }
        // A new place to read from: the words heard before it must not match back where they were read.
        speech.discardHeard()
        speechTracker.reset(to: scriptWords.wordIndex(
            atOffset: engine.offset, paragraphFrames: paragraphFrames, lineHeight: lineHeight, endOffset: engine.endOffset
        ))
        speechLead.reset(to: speechTracker.position)
    }
}
