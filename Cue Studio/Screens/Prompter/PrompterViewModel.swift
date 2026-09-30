//
//  PrompterViewModel.swift
//  Cue Studio
//

import Foundation

/// Everything that happens while the prompter is open: scrolling, the camera, recording and the
/// hand-off to take review. Reads and changes settings through `session` (the Creator Setup, the
/// platform recommendation the creator accepted and this take's changes), never the stored
/// defaults directly.
@MainActor
@Observable
final class PrompterViewModel {
    private(set) var scriptID: UUID?
    private(set) var mode: PrompterMode
    private(set) var engine = PrompterScrollEngine()
    private(set) var isPlaying = false

    // MARK: Recording state
    private(set) var isRecording = false
    private(set) var recordingSeconds = 0
    private(set) var countdown: Int?
    private(set) var showsStopWarning = false

    // MARK: Voice follow
    private(set) var isVoiceActive = false
    /// 0...1, for the live mic indicator.
    private(set) var voiceLevel: Double = 0
    /// True while speech recognition follows the reading word by word. Without it (no model for
    /// the language, or still downloading), Voice follow scrolls at the set speed while it hears
    /// speech.
    private(set) var followsSpeech = false
    /// The language recognition listens in while `followsSpeech`.
    private(set) var listeningLanguage: CueLanguage?
    /// Why the words can't be followed in this language here, shown to the creator (once as a
    /// toast, and under the Studio controls). Never replaced by another language.
    private(set) var speechUnavailable: SpeechUnavailableReason?

    // MARK: Presentation
    var sheet: PrompterSheet? {
        didSet {
            if oldValue == nil, sheet != nil { sheetCeiling = textWindowBottom }
        }
    }
    /// Bottom of the Selfie text window when the open sheet appeared: sheets stop below it so the
    /// script stays in sight. Kept while the sheet is open, so changing the layout in Display
    /// doesn't move the sheet under the finger.
    private(set) var sheetCeiling: CGFloat?
    var reviewingTake: Take?
    /// True when the prompter opened straight on a take (from the Takes tab).
    private(set) var openedOnReview: Bool

    // MARK: Selfie layout (see PrompterViewModel+Layout)
    /// What the Selfie screen measured on this device.
    private(set) var screenMetrics = SelfieScreenMetrics()
    /// The safe zone picked in Display › Layout, for this session.
    private(set) var safeZonePick: SafeZoneChoice?
    /// Hidden with the eye button, or from the start with "Hide controls while recording".
    private(set) var controlsHidden = false

    /// This recording's setup. Views read and bind `session.camera` / `session.prompter`.
    let session: SessionSetupService

    private let library: ScriptLibraryService
    private let takes: TakeLibraryService
    private let profile: CreatorProfileService
    let rules: PlatformRulesService
    private let camera: CameraControlling
    private let audio: AudioLevelMetering
    private let microphones: MicrophoneListing
    private let speech: SpeechTranscribing
    private let languages: LanguageService
    let remote: RemoteControlService
    let toast: ToastService

    private var driver: DisplayLinkDriver?
    private var countdownTask: Task<Void, Never>?
    private var recordingClock: Task<Void, Never>?
    private var autoStopTask: Task<Void, Never>?
    private var voiceTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?
    private var voiceGate = VoiceFollowGate()
    private var scriptWords = ScriptWords(text: "")
    private var speechTracker = ScriptSpeechTracker(words: [])
    /// Vertical extent of each paragraph in the text, for placing words on the guide.
    private var paragraphFrames: [Range<Double>] = []
    private var hasStartedSession = false
    /// The camera and mic the creator was already told are missing, so the notice shows once.
    private var noticedLens: CameraLens?
    private var noticedMicrophone: MicrophoneChoice?
    /// The unavailable language the creator was already told about, so the toast shows once.
    private var noticedSpeechUnavailable: SpeechUnavailableReason?

    init(
        launch: PrompterLaunch,
        library: ScriptLibraryService,
        takes: TakeLibraryService,
        preferences: PreferencesService,
        profile: CreatorProfileService,
        rules: PlatformRulesService,
        camera: CameraControlling,
        audio: AudioLevelMetering,
        microphones: MicrophoneListing,
        speech: SpeechTranscribing,
        languages: LanguageService,
        remote: RemoteControlService,
        toast: ToastService
    ) {
        scriptID = launch.scriptID
        mode = launch.mode
        session = SessionSetupService(preferences: preferences)
        self.library = library
        self.takes = takes
        self.profile = profile
        self.rules = rules
        self.camera = camera
        self.audio = audio
        self.microphones = microphones
        self.speech = speech
        self.languages = languages
        self.remote = remote
        self.toast = toast
        reviewingTake = takes.take(id: launch.reviewTakeID)
        openedOnReview = launch.reviewTakeID != nil
    }

    // MARK: - Reading

    var script: Script? { library.script(id: scriptID) }

    var hasScript: Bool { script != nil }

    var paragraphs: [String] { CueParser.paragraphs(in: script?.text ?? "") }

    /// Which way the script reads: its language's direction, whatever the interface's is. The
    /// text view asks every frame, so the answer is kept until the script changes.
    var readsRightToLeft: Bool {
        guard let script else { return false }
        let key = DirectionKey(language: script.language, text: script.text)
        if let cached = directionCache, cached.key == key { return cached.rightToLeft }
        let rightToLeft = ScriptDirection.isRightToLeft(language: script.language, text: script.text)
        directionCache = (key, rightToLeft)
        return rightToLeft
    }

    private struct DirectionKey: Equatable {
        let language: CueLanguage?
        let text: String
    }

    @ObservationIgnored private var directionCache: (key: DirectionKey, rightToLeft: Bool)?

    var preset: PlatformPreset? {
        script.map { rules.preset(for: $0.platform, monetizationGoals: profile.profile.monetizationGoals) }
    }

    /// What Cue recommends for this script's platform. Nil freestyle.
    var recommendation: SetupRecommendation? {
        guard let script, let preset else { return nil }
        return SetupRecommendation(platform: script.platform, preset: preset)
    }

    /// Studio text is read from further away, so it is bigger.
    var fontSize: Double {
        let size = session.prompter.size
        return mode == .studio ? (size * PrompterSettings.studioScale).rounded() : size
    }

    var lineHeight: Double { fontSize * session.prompter.lineSpacing }

    /// Newest take of this script (or of freestyle recordings).
    var lastTake: Take? {
        takes.takes.first { $0.scriptID == scriptID }
    }

    var cameraStatus: CameraStatus { camera.status }

    var monetizationChip: String? {
        guard isRecording, hasScript else { return nil }
        return MonetizationCheck.chipLabel(elapsed: TimeInterval(recordingSeconds), preset: preset)
    }

    var stopWarningTitle: String? {
        MonetizationCheck.warningTitle(elapsed: TimeInterval(recordingSeconds), preset: preset)
    }

    var stopWarningMessage: String? { preset?.goal?.stopWarning }

    // MARK: - Lifecycle

    func appear() async {
        startSessionOnce()
        remote.attach(
            onCommand: { [weak self] command in self?.handle(command) },
            status: { [weak self] in self?.remoteStatus ?? .idle }
        )
        guard reviewingTake == nil else { return }
        await enter(mode)
    }

    func disappear() async {
        countdownTask?.cancel()
        autoStopTask?.cancel()
        voiceTask?.cancel()
        stopFollowingSpeech()
        pause()
        if isRecording { await stopRecording(openReview: false) }
        remote.detach()
        audio.stopMetering()
        await camera.stop()
    }

    func switchMode(to newMode: PrompterMode) async {
        guard newMode != mode, !isRecording, countdown == nil else { return }
        pause()
        mode = newMode
        await enter(newMode)
    }

    private func enter(_ mode: PrompterMode) async {
        switch mode {
        case .selfie:
            audio.stopMetering()
            await camera.start(with: session.camera)
            noticeCaptureFallbacks()
        case .studio:
            await camera.stop()
        }
        updateVoiceMonitoring()
    }

    /// Once per session: the recording starts from the Creator Setup, the script's platform
    /// recommendation is offered (never applied on its own) and the text window opens at its full
    /// size.
    private func startSessionOnce() {
        guard !hasStartedSession else { return }
        hasStartedSession = true
        session.recommend(recommendation)
        guard hasScript else { return }
        var prompter = session.prompter
        prompter.readingWidth = PrompterSettings.defaultReadingWidth
        prompter.textWindowHeight = PrompterSettings.defaultTextWindowHeight
        session.prompter = prompter
    }

    /// "Create for" from the camera: the script moves to the platform, whose setup is offered.
    func setPlatform(_ platform: Platform) {
        guard let scriptID else { return }
        library.update(scriptID) { $0.platform = platform }
        sheet = nil
        session.recommend(recommendation)
        toast.show(String(localized: "Create for \(platform.destinationName)"))
    }

    /// The chip next to the mode switch: with a script it opens "Create for"; freestyle it cycles
    /// the frame.
    func platformChipTapped() {
        if hasScript {
            sheet = .destination
        } else {
            cycleAspect()
        }
    }

    func setScrollMode(_ mode: ScrollMode) {
        guard session.prompter.scrollMode != mode else { return }
        session.prompter.scrollMode = mode
    }

    // MARK: - Scrolling

    func updateLayout(contentHeight: Double) {
        engine.updateLayout(
            contentHeight: contentHeight,
            lineHeight: lineHeight,
            wordCount: ReadTime.wordCount(in: script?.text ?? "")
        )
    }

    /// Where paragraph `index` sits in the text (top..<bottom), for Voice follow.
    func updateParagraphFrame(_ frame: Range<Double>, at index: Int) {
        guard index >= 0 else { return }
        if paragraphFrames.count <= index {
            paragraphFrames += Array(repeating: frame, count: index + 1 - paragraphFrames.count)
        }
        paragraphFrames[index] = frame
    }

    func togglePlay() {
        guard hasScript else { return }
        isPlaying ? pause() : play()
    }

    func play() {
        guard hasScript else { return }
        if engine.isAtEnd {
            engine.rewind()
            speechTracker.reset(to: 0)
        }
        isPlaying = true
        if driver == nil {
            driver = DisplayLinkDriver { [weak self] seconds in self?.advance(by: seconds) }
        }
        driver?.start()
        publishRemoteStatus()
    }

    func pause() {
        isPlaying = false
        driver?.stop()
        publishRemoteStatus()
    }

    func rewind() {
        engine.rewind()
        speechTracker.reset(to: 0)
        pause()
        toast.show(String(localized: "Back to the top"))
    }

    func jump(lines: Int) {
        engine.jump(lines: lines)
        syncSpeechPosition()
    }

    /// Dragging the text: finger up moves the script forward.
    func drag(by translation: Double) {
        engine.scroll(by: -translation)
        syncSpeechPosition()
    }

    /// One frame of scrolling.
    func advance(by seconds: Double) {
        guard isPlaying else { return }
        let reachedEnd: Bool
        let settings = session.prompter
        switch settings.scrollMode {
        case .voice where followsSpeech:
            guard let target = speechTarget else { return }
            reachedEnd = engine.glide(toward: target, by: seconds)
        case .voice:
            guard isVoiceActive else { return }
            reachedEnd = engine.advance(by: seconds, speed: settings.speed)
        case .steady:
            reachedEnd = engine.advance(by: seconds, speed: settings.speed)
        }
        if reachedEnd {
            pause()
            scriptDidEnd()
        }
    }

    /// The speed slider: tenths, within the range. For this session; the default speed is in
    /// Creator Setup.
    func setSpeed(_ value: Double) {
        let speed = PrompterSettings.clampedSpeed(value)
        guard speed != session.prompter.speed else { return }
        session.prompter.speed = speed
        publishRemoteStatus()
    }

    // MARK: - Recording

    /// The big red button: starts the countdown, cancels it, or stops the take (warning first when
    /// stopping short of the monetization minimum).
    func recordButtonTapped() async {
        if countdown != nil {
            cancelCountdown()
            return
        }
        if isRecording {
            if !showsStopWarning, hasScript,
               MonetizationCheck.secondsMissing(elapsed: TimeInterval(recordingSeconds), preset: preset) != nil {
                showsStopWarning = true
                return
            }
            await stopRecording()
            return
        }
        guard camera.status == .running else {
            toast.show(String(localized: "The camera isn't ready"))
            return
        }
        let seconds = session.camera.countdown.rawValue
        if seconds > 0 {
            startCountdown(from: seconds)
        } else {
            await beginRecording()
        }
    }

    func keepRecording() {
        showsStopWarning = false
    }

    func stopAnyway() async {
        await stopRecording()
    }

    private func startCountdown(from seconds: Int) {
        pause()
        sheet = nil
        countdown = seconds
        countdownTask = Task { [weak self] in
            for remaining in stride(from: seconds, to: 0, by: -1) {
                self?.countdown = remaining
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            self?.countdown = nil
            await self?.beginRecording()
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil
    }

    private func beginRecording() async {
        // Recording without answering the recommendation keeps the Creator Setup, which is what the
        // screen showed.
        session.settleUndecided()
        do {
            try await camera.startRecording(settings: session.camera)
        } catch {
            toast.show(error.localizedDescription)
            return
        }
        isRecording = true
        recordingSeconds = 0
        showsStopWarning = false
        controlsHidden = session.prompter.hidesControlsWhileRecording
        noticeCaptureFallbacks()
        if hasScript && session.camera.scrollsWithRecording {
            play()
        } else {
            publishRemoteStatus()
        }
        recordingClock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.recordingSeconds += 1
            }
        }
    }

    /// Stops the take, files it in the library and opens its review.
    func stopRecording(openReview: Bool = true) async {
        guard isRecording else { return }
        recordingClock?.cancel()
        autoStopTask?.cancel()
        showsStopWarning = false
        pause()
        let clip = await camera.stopRecording()
        isRecording = false
        controlsHidden = false
        guard let clip else {
            toast.show(String(localized: "The take couldn't be saved"))
            return
        }
        do {
            let take = try takes.addTake(
                fileAt: clip.url, duration: clip.duration, script: script, camera: session.camera, background: camera.background
            )
            if openReview { reviewingTake = take }
        } catch {
            toast.show(String(localized: "The take couldn't be saved"))
        }
    }

    /// "Stop when script ends": a short beat after the last line, then stop.
    private func scriptDidEnd() {
        guard isRecording, session.camera.stopsWhenScriptEnds else { return }
        autoStopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self, !Task.isCancelled, self.isRecording else { return }
            await self.stopRecording()
        }
    }

    // MARK: - Selfie layout state

    /// Applies what the Selfie screen measured, only when something changed.
    func measured(_ update: (inout SelfieScreenMetrics) -> Void) {
        var metrics = screenMetrics
        update(&metrics)
        guard metrics != screenMetrics else { return }
        screenMetrics = metrics
    }

    func pickSafeZone(_ choice: SafeZoneChoice) {
        safeZonePick = choice
    }

    /// The eye button while recording.
    func toggleControls() {
        guard isRecording else { return }
        controlsHidden.toggle()
    }

    /// "Reset to Recommended" also forgets the safe zone picked in this session.
    func forgetSafeZonePick() {
        safeZonePick = nil
    }

    // MARK: - Review

    func retake() async {
        reviewingTake = nil
        openedOnReview = false
        engine.rewind()
        mode = .selfie
        await enter(.selfie)
    }

    func openLastTake() {
        guard let lastTake, !isRecording else { return }
        pause()
        reviewingTake = lastTake
    }

    // MARK: - Script

    /// Adds a script to a freestyle session. The camera keeps its current frame; the script's
    /// platform setup is offered.
    func attach(_ script: Script) {
        scriptID = script.id
        engine = PrompterScrollEngine()
        paragraphFrames = []
        sheet = nil
        session.recommend(recommendation)
        updateVoiceMonitoring()
        toast.show(String(localized: "Script added"))
    }

    // MARK: - Camera controls

    /// Frame, lens and the rest change for this take; Creator Setup keeps the defaults.
    func cycleAspect() {
        session.camera.aspect = session.camera.aspect.next
    }

    func flipCamera() {
        session.camera.lens = session.camera.lens.isFront ? .wide : .front
    }

    /// The microphone pill: the input can't change mid-take (or while the countdown runs into one).
    var canChangeAudioInput: Bool { !isRecording && countdown == nil }

    func openAudioInput() {
        guard canChangeAudioInput else { return }
        sheet = .audioInput
    }

    func cycleCountdown() {
        session.camera.countdown = session.camera.countdown.next
    }

    func cameraSettingsChanged() async {
        guard mode == .selfie, !isRecording else { return }
        await camera.apply(session.camera)
        noticeCaptureFallbacks()
    }

    /// When the camera or microphone asked for isn't on this device right now, the take records
    /// with another one instead of failing, and a toast says so, once for each ("AirPods Pro
    /// unavailable · Using iPhone Microphone instead"). Cue doesn't touch Bluetooth itself.
    private func noticeCaptureFallbacks() {
        let requested = session.camera
        if let active = camera.activeLens, active != requested.lens, noticedLens != requested.lens {
            noticedLens = requested.lens
            toast.show(String(localized: "\(requested.lens.label) unavailable · Using \(active.label) instead"))
            return
        }
        let microphone = MicrophoneChoice(id: requested.microphoneID, name: requested.microphoneName)
        guard microphone != .automatic, microphone != noticedMicrophone else { return }
        microphones.refreshInputs()
        guard let notice = MicrophoneFallback.notice(for: microphone, available: microphones.inputs, inUse: microphones.inputInUse) else { return }
        noticedMicrophone = microphone
        toast.show(notice)
    }

    // MARK: - Voice follow

    func scrollModeChanged() {
        updateVoiceMonitoring()
    }

    /// Speech recognition moves the text to the word being read (see `followSpeech`). The level
    /// drives the mic indicator, and scrolling too when recognition isn't available. In Selfie mode
    /// both come from the camera's audio; in Studio mode from a meter of their own.
    private func updateVoiceMonitoring() {
        voiceTask?.cancel()
        voiceTask = nil
        stopFollowingSpeech()
        guard session.prompter.scrollMode == .voice, let script else {
            isVoiceActive = false
            voiceLevel = 0
            speechUnavailable = nil
            audio.stopMetering()
            return
        }
        let text = script.text
        let language = languages.speechRequest(for: script)
        speechTask = Task { [weak self] in
            await self?.followSpeech(in: text, language: language)
        }
        voiceTask = Task { [weak self] in
            if self?.mode == .studio {
                _ = await self?.audio.startMetering()
            }
            while !Task.isCancelled {
                guard let self else { return }
                let level: Float? = self.mode == .selfie ? await self.camera.audioPowerLevel() : self.audio.powerLevel
                self.isVoiceActive = self.voiceGate.isSpeaking(level: level, at: ProcessInfo.processInfo.systemUptime)
                self.voiceLevel = VoiceFollowGate.normalized(level)
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    /// Listens for the script being read, in the Voice Following language (or the script's), and
    /// keeps the tracker on the next word to read. A language this device can't recognize is never
    /// swapped for another: the text follows the voice level and the creator is told why.
    private func followSpeech(in text: String, language: SpeechLanguageRequest) async {
        let transcription: SpeechTranscription
        switch await speech.start(script: text, language: language) {
        case .listening(let started, let route):
            guard !Task.isCancelled else { return }
            transcription = started
            listeningLanguage = route.language
            speechUnavailable = nil
        case .unavailable(let reason):
            guard !Task.isCancelled else { return }
            speechUnavailable = reason
            if noticedSpeechUnavailable != reason {
                noticedSpeechUnavailable = reason
                toast.show(reason.message)
            }
            return
        case .cancelled:
            return
        }
        switch mode {
        case .selfie: camera.setAudioHandler(transcription.audio)
        case .studio: audio.setAudioHandler(transcription.audio)
        }
        scriptWords = ScriptWords(text: text)
        speechTracker = ScriptSpeechTracker(words: scriptWords.tokens)
        followsSpeech = true
        syncSpeechPosition()
        for await heard in transcription.transcripts {
            speechTracker.hear(heard)
        }
        // Recognition ended on its own: fall back to the level. A cancelled task was replaced.
        if !Task.isCancelled { followsSpeech = false }
    }

    private func stopFollowingSpeech() {
        speechTask?.cancel()
        speechTask = nil
        followsSpeech = false
        listeningLanguage = nil
        camera.setAudioHandler(nil)
        audio.setAudioHandler(nil)
        speech.stop()
    }

    /// Where the next word to read sits on the guide.
    private var speechTarget: Double? {
        scriptWords.offset(
            forWord: speechTracker.position,
            paragraphFrames: paragraphFrames,
            lineHeight: lineHeight,
            endOffset: engine.endOffset
        )
    }

    /// After a manual scroll, reading picks up from what's on the guide.
    private func syncSpeechPosition() {
        guard followsSpeech else { return }
        speechTracker.reset(to: scriptWords.wordIndex(
            atOffset: engine.offset,
            paragraphFrames: paragraphFrames,
            lineHeight: lineHeight,
            endOffset: engine.endOffset
        ))
    }
}
