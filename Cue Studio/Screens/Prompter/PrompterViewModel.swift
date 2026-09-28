//
//  PrompterViewModel.swift
//  Cue Studio
//

import Foundation

/// Everything that happens while the prompter is open: scrolling, the camera, recording and the
/// hand-off to take review.
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
    /// the script's language, or still downloading), Voice follow scrolls at the set speed while
    /// it hears speech.
    private(set) var followsSpeech = false

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

    private let library: ScriptLibraryService
    private let takes: TakeLibraryService
    let preferences: PreferencesService
    private let profile: CreatorProfileService
    let rules: PlatformRulesService
    private let camera: CameraControlling
    private let audio: AudioLevelMetering
    private let speech: SpeechTranscribing
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
    private var hasAppliedPreset = false

    init(
        launch: PrompterLaunch,
        library: ScriptLibraryService,
        takes: TakeLibraryService,
        preferences: PreferencesService,
        profile: CreatorProfileService,
        rules: PlatformRulesService,
        camera: CameraControlling,
        audio: AudioLevelMetering,
        speech: SpeechTranscribing,
        toast: ToastService
    ) {
        scriptID = launch.scriptID
        mode = launch.mode
        self.library = library
        self.takes = takes
        self.preferences = preferences
        self.profile = profile
        self.rules = rules
        self.camera = camera
        self.audio = audio
        self.speech = speech
        self.toast = toast
        reviewingTake = takes.take(id: launch.reviewTakeID)
        openedOnReview = launch.reviewTakeID != nil
    }

    // MARK: - Reading

    var script: Script? { library.script(id: scriptID) }

    var hasScript: Bool { script != nil }

    var paragraphs: [String] { CueParser.paragraphs(in: script?.text ?? "") }

    var preset: PlatformPreset? {
        script.map { rules.preset(for: $0.platform, monetizationGoals: profile.profile.monetizationGoals) }
    }

    /// Studio text is read from further away, so it is bigger.
    var fontSize: Double {
        let size = preferences.prompter.size
        return mode == .studio ? (size * PrompterSettings.studioScale).rounded() : size
    }

    var lineHeight: Double { fontSize * preferences.prompter.lineSpacing }

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
        applyPresetOnce()
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
            await camera.start(with: preferences.camera)
        case .studio:
            await camera.stop()
        }
        updateVoiceMonitoring()
    }

    /// A script opens with its platform's frame, resolution and frame rate, and the text window at
    /// its full size, once per session; after that the creator's changes stand.
    private func applyPresetOnce() {
        guard !hasAppliedPreset, let preset else { return }
        hasAppliedPreset = true
        apply(preset)
    }

    private func apply(_ preset: PlatformPreset) {
        preferences.camera.apply(preset)
        preferences.prompter.readingWidth = PrompterSettings.defaultReadingWidth
        preferences.prompter.textWindowHeight = PrompterSettings.defaultTextWindowHeight
    }

    /// "Create for" from the camera: the script moves to the platform and the camera takes its preset.
    func setPlatform(_ platform: Platform) {
        guard let scriptID else { return }
        library.update(scriptID) { $0.platform = platform }
        sheet = nil
        if let preset { apply(preset) }
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
        guard preferences.prompter.scrollMode != mode else { return }
        preferences.prompter.scrollMode = mode
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
    }

    func pause() {
        isPlaying = false
        driver?.stop()
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
        switch preferences.prompter.scrollMode {
        case .voice where followsSpeech:
            guard let target = speechTarget else { return }
            reachedEnd = engine.glide(toward: target, by: seconds)
        case .voice:
            guard isVoiceActive else { return }
            reachedEnd = engine.advance(by: seconds, speed: preferences.prompter.speed)
        case .steady:
            reachedEnd = engine.advance(by: seconds, speed: preferences.prompter.speed)
        }
        if reachedEnd {
            pause()
            scriptDidEnd()
        }
    }

    /// The speed slider: tenths, within the range.
    func setSpeed(_ value: Double) {
        let speed = PrompterSettings.clampedSpeed(value)
        guard speed != preferences.prompter.speed else { return }
        preferences.prompter.speed = speed
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
        let seconds = preferences.camera.countdown.rawValue
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
        do {
            try await camera.startRecording(settings: preferences.camera)
        } catch {
            toast.show(error.localizedDescription)
            return
        }
        isRecording = true
        recordingSeconds = 0
        showsStopWarning = false
        controlsHidden = preferences.prompter.hidesControlsWhileRecording
        if hasScript && preferences.camera.scrollsWithRecording {
            play()
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
            let take = try takes.addTake(fileAt: clip.url, duration: clip.duration, script: script, camera: preferences.camera)
            if openReview { reviewingTake = take }
        } catch {
            toast.show(String(localized: "The take couldn't be saved"))
        }
    }

    /// "Stop when script ends": a short beat after the last line, then stop.
    private func scriptDidEnd() {
        guard isRecording, preferences.camera.stopsWhenScriptEnds else { return }
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

    /// Adds a script to a freestyle session. The camera keeps its current frame.
    func attach(_ script: Script) {
        scriptID = script.id
        engine = PrompterScrollEngine()
        paragraphFrames = []
        sheet = nil
        updateVoiceMonitoring()
        toast.show(String(localized: "Script added"))
    }

    // MARK: - Camera controls

    func cycleAspect() {
        preferences.camera.aspect = preferences.camera.aspect.next
    }

    func flipCamera() {
        preferences.camera.lens = preferences.camera.lens.isFront ? .wide : .front
    }

    func cycleCountdown() {
        preferences.camera.countdown = preferences.camera.countdown.next
    }

    func cameraSettingsChanged() async {
        guard mode == .selfie, !isRecording else { return }
        await camera.apply(preferences.camera)
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
        guard preferences.prompter.scrollMode == .voice, let script else {
            isVoiceActive = false
            voiceLevel = 0
            audio.stopMetering()
            return
        }
        let text = script.text
        speechTask = Task { [weak self] in
            await self?.followSpeech(in: text)
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

    /// Listens for the script being read and keeps the tracker on the next word to read.
    private func followSpeech(in text: String) async {
        guard let transcription = await speech.start(script: text), !Task.isCancelled else { return }
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
