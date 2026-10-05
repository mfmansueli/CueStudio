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
    var reviewStartsWithPick = false
    private(set) var showsStopWarning = false
    /// The compact recording bar and the whole one a tap brings back.
    let bar = RecordingBarState()

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
    /// What recognition waits for before it can follow the words: its model loading, or
    /// downloading. Nil once it listens, or when it can't.
    private(set) var speechPreparation: SpeechPreparation?
    /// How quickly the text catches up with the words heard.
    var voiceGlide = VoiceGlide()
    /// How far, in words, the text may run ahead of the last word recognized while the creator
    /// speaks (0 waits for every word).
    var maximumSpeechLead: Double {
        get { speechLead.maximumWords }
        set { speechLead.maximumWords = newValue }
    }
    /// This session's Voice Following timings, for tuning (see `VoiceFollowMetrics`).
    private(set) var voiceMetrics = VoiceFollowMetrics()

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
    /// The first flight's practice run: nothing is recorded.
    private(set) var isPractice: Bool

    // MARK: Selfie layout (see PrompterViewModel+Layout)
    /// What the Selfie screen measured on this device.
    var screenMetrics = SelfieScreenMetrics()
    /// The safe zone picked in Display › Layout, for this session.
    var safeZonePick: SafeZoneChoice?

    /// This recording's setup. Views read and bind `session.camera` / `session.prompter`.
    let session: SessionSetupService

    private let library: ScriptLibraryService
    let takes: TakeLibraryService
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
    private var levelTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?
    /// What the running recognition listens for. Another script or language starts a new one;
    /// switching between Selfie and Studio keeps it.
    private var speechSession: SpeechSession?
    /// Bumped whenever recognition stops, so what a stopped start still reports is ignored.
    private var speechGeneration = 0
    private var transcription: SpeechTranscription?
    private var voiceGate = VoiceFollowGate()
    private var speechLead = SpeechLead()
    /// When the level meter last changed, so it redraws at most `levelInterval` apart.
    private var levelShownAt: TimeInterval = 0
    private var scriptWords = ScriptWords(text: "")
    private var speechTracker = ScriptSpeechTracker(words: [])
    /// Vertical extent of each paragraph in the text, for placing words on the guide.
    private(set) var paragraphFrames: [Range<Double>] = []
    /// The word each mode was left on (see `keepPlace`).
    private var readingPlaces: [PrompterMode: Int] = [:]
    /// The word to put back on the guide until the layout of the mode just entered has settled.
    private var layoutAnchor: LayoutAnchor?
    private var hasStartedSession = false
    /// The camera and mic the creator was already told are missing, so the notice shows once.
    private var noticedLens: CameraLens?
    private var noticedMicrophone: MicrophoneChoice?
    /// The unavailable language the creator was already told about, so the toast shows once.
    private var noticedSpeechUnavailable: SpeechUnavailableReason?
    /// Seconds on the same clock as the microphone's buffers (`AudioLevelSample.time`).
    private let clock: () -> TimeInterval

    /// Script text and language a recognition was started for.
    private struct SpeechSession: Equatable {
        let text: String
        let language: SpeechLanguageRequest
    }

    /// The level meter redraws at most this often; buffers arrive every 20–100 ms.
    private static let levelInterval: TimeInterval = 0.05

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
        toast: ToastService,
        clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
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
        self.clock = clock
        reviewingTake = takes.take(id: launch.reviewTakeID)
        openedOnReview = launch.reviewTakeID != nil
        isPractice = launch.isPractice
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

    /// The lens Selfie had, kept while Studio records through the rear camera.
    @ObservationIgnored private var studioReturnLens: CameraLens?
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
        camera.onRecordingEnded = { [weak self] clip, reason in self?.recordingEndedByItself(clip, reason: reason) }
        guard reviewingTake == nil else { return }
        await enter(mode)
    }

    func disappear() async {
        countdownTask?.cancel()
        autoStopTask?.cancel()
        stopVoiceMonitoring()
        pause()
        if isRecording { await stopRecording(openReview: false) }
        remote.detach()
        camera.onRecordingEnded = nil
        await camera.stop()
    }

    func switchMode(to newMode: PrompterMode) async {
        guard newMode != mode, !isRecording, countdown == nil else { return }
        pause()
        if let word = wordOnTheGuide() { readingPlaces[mode] = word }
        mode = newMode
        putBackPlace(of: newMode)
        await enter(newMode)
    }

    private func enter(_ mode: PrompterMode) async {
        // Recognition gets ready while the camera starts: neither needs the other.
        startSpeechIfNeeded()
        switch mode {
        case .selfie:
            audio.stopMetering()
            // Back from Studio: the lens the creator had.
            if let lens = studioReturnLens {
                session.camera.lens = lens
                studioReturnLens = nil
            }
            await camera.start(with: session.camera)
            noticeCaptureFallbacks()
        case .studio:
            // Studio records too (v29 · 5.3): through the rear camera, behind the glass of a rig, while the screen
            // shows the text. Its lens is for this take only.
            audio.stopMetering()
            if studioReturnLens == nil { studioReturnLens = session.camera.lens }
            session.camera.lens = .wide
            await camera.start(with: session.camera)
            noticeCaptureFallbacks()
        }
        updateVoiceMonitoring()
    }

    /// Once per session: offer the script's platform recommendation without changing the
    /// creator's saved reading preferences or explicit session adjustments.
    private func startSessionOnce() {
        guard !hasStartedSession else { return }
        hasStartedSession = true
        session.recommend(recommendation)
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
        reanchorToReadingWord()
    }

    /// Where paragraph `index` sits in the text (top..<bottom), for Voice follow.
    func updateParagraphFrame(_ frame: Range<Double>, at index: Int) {
        guard index >= 0 else { return }
        if paragraphFrames.count <= index {
            paragraphFrames += Array(repeating: frame, count: index + 1 - paragraphFrames.count)
        }
        paragraphFrames[index] = frame
        reanchorToReadingWord()
    }

    /// The words the script is counted in, the ones recognition follows while it does.
    private func currentWords() -> ScriptWords? {
        guard let script else { return nil }
        let words = followsSpeech ? scriptWords : ScriptWords(text: script.text, language: script.language)
        return words.count > 0 ? words : nil
    }

    /// The word on the guide now, in this mode's layout.
    private func wordOnTheGuide() -> Int? {
        guard !paragraphFrames.isEmpty, let words = currentWords() else { return nil }
        return words.wordIndex(
            atOffset: engine.offset, paragraphFrames: paragraphFrames, lineHeight: lineHeight, endOffset: engine.endOffset
        )
    }

    /// Each mode keeps its own place (`readingPlaces`, noted before the mode changes, while the
    /// layout is still its own): coming back puts that word on the guide again, and a mode not
    /// visited yet starts at the top, so what one does never moves the other.
    private func putBackPlace(of newMode: PrompterMode) {
        guard let words = currentWords() else { return }
        let word = readingPlaces[newMode] ?? 0
        layoutAnchor = LayoutAnchor(words: words, word: word, until: clock() + LayoutAnchor.settling)
        resumeSpeech(at: word)
    }

    /// Reads on from `word` with a fresh transcript: the words heard before are still in the
    /// transcript's last words, and would match where they were read.
    private func resumeSpeech(at word: Int) {
        guard followsSpeech else { return }
        speech.discardHeard()
        speechTracker.reset(to: word)
        speechLead.reset(to: word)
    }

    /// Puts the word that was on the guide back on it, each time the new layout reports a part of
    /// itself, until the swap has settled. The last report has the final measures.
    private func reanchorToReadingWord() {
        guard let anchor = layoutAnchor else { return }
        guard clock() < anchor.until else {
            layoutAnchor = nil
            return
        }
        guard let offset = anchor.words.offset(
            forWord: anchor.word, paragraphFrames: paragraphFrames, lineHeight: lineHeight, endOffset: engine.endOffset
        ) else { return }
        engine.seek(to: offset)
        if followsSpeech {
            speechTracker.reset(to: anchor.word)
            speechLead.reset(to: anchor.word)
        }
    }

    func togglePlay() {
        guard hasScript else { return }
        if isPlaying { pause() } else { play() }
    }

    func play() {
        guard hasScript else { return }
        if engine.isAtEnd {
            engine.rewind()
            resumeSpeech(at: 0)
        }
        // Nothing predicted carries over a pause.
        speechLead.reset(to: speechTracker.position)
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

    /// "Record it for real": the practice ends and the text goes back to the top.
    func leavePractice() {
        guard isPractice else { return }
        pause(); isPractice = false; layoutAnchor = nil; engine.rewind(); resumeSpeech(at: 0)
    }

    /// The practice starts on its own: the text follows the voice from the first word.
    func startPractice() { if isPractice, !isPlaying { play() } }

    func rewind() {
        layoutAnchor = nil
        engine.rewind()
        resumeSpeech(at: 0)
        pause()
        toast.show(String(localized: "Back to the top"))
    }

    func jump(lines: Int) {
        layoutAnchor = nil
        engine.jump(lines: lines)
        syncSpeechPosition()
    }

    /// Dragging the text: finger up moves the script forward.
    func drag(by translation: Double) {
        layoutAnchor = nil
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
            let now = clock()
            showVoice(voiceGate.isSpeaking(at: now), heardAt: now)
            speechLead.advance(to: now, quiet: voiceGate.quietTime(at: now))
            guard let target = speechTarget else { return }
            let start = engine.offset
            let glideTime = voiceGlide.time(forDistance: target - start, lineHeight: lineHeight)
            reachedEnd = engine.glide(toward: target, by: seconds, glideTime: glideTime)
            if engine.offset > start { voiceMetrics.moved(at: now) }
        case .voice:
            let now = clock()
            showVoice(voiceGate.isSpeaking(at: now), heardAt: now)
            guard isVoiceActive else { return }
            reachedEnd = engine.advance(by: seconds, speed: settings.speed)
            voiceMetrics.moved(at: now)
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
            Haptics.record()
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
        bar.collapse()
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
        bar.collapse()
        file(clip, openReview: openReview, message: nil)
    }

    /// The take ended on its own: the storage filled up or a call took the camera. What the system could finish is filed as a take,
    /// and a toast says why it stopped (04 · F3).
    func recordingEndedByItself(_ clip: RecordedClip?, reason: RecordingEndReason) {
        guard isRecording else { return }
        recordingClock?.cancel()
        autoStopTask?.cancel()
        showsStopWarning = false
        pause()
        isRecording = false
        bar.collapse()
        file(clip, openReview: true, message: reason.toast)
    }

    /// The recorded clip becomes a take; `message` (why it stopped) replaces nothing when the take can't be saved.
    private func file(_ clip: RecordedClip?, openReview: Bool, message: String?) {
        guard let clip else {
            toast.show(String(localized: "The take couldn't be saved"))
            return
        }
        do {
            let take = try takes.addTake(
                fileAt: clip.url, duration: clip.duration, script: script, camera: session.camera, background: camera.background
            )
            if openReview {
                reviewStartsWithPick = shouldPickBest(after: take)
                reviewingTake = take
            }
            if let message { toast.show(message) }
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

    // MARK: - Review

    func retake() async {
        reviewingTake = nil
        openedOnReview = false
        engine.rewind()
        resumeSpeech(at: 0)
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
        readingPlaces = [:]
        layoutAnchor = nil
        sheet = nil
        session.recommend(recommendation)
        updateVoiceMonitoring()
        toast.show(String(localized: "Script added"))
    }

    // MARK: - Camera controls

    func cameraSettingsChanged() async {
        guard !isRecording else { return }
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
            toast.show(String(localized: "No \(requested.lens.label) · Using \(active.label)"))
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

    /// What the voice indicator and Studio's line say.
    var voiceFollowStatus: VoiceFollowStatus {
        VoiceFollowStatus(followsSpeech: followsSpeech, preparation: speechPreparation)
    }

    /// Speech recognition moves the text to the word being read (see `followSpeech`); the level of
    /// each buffer, as it arrives, lights the indicator, lets the text run a little ahead of the
    /// words (`SpeechLead`) and drives scrolling when recognition isn't available. In Selfie mode
    /// both come from the camera's audio; in Studio mode from a meter of their own.
    private func updateVoiceMonitoring() {
        guard session.prompter.scrollMode == .voice, script != nil else {
            stopVoiceMonitoring()
            return
        }
        startSpeechIfNeeded()
        routeSpeechAudio()
        listenForVoice()
    }

    private func stopVoiceMonitoring() {
        levelTask?.cancel()
        levelTask = nil
        camera.setLevelHandler(nil)
        audio.setLevelHandler(nil)
        stopFollowingSpeech()
        isVoiceActive = false
        voiceLevel = 0
        speechUnavailable = nil
        voiceGate = VoiceFollowGate()
        audio.stopMetering()
    }

    /// Starts recognition for the script in Voice Following's language, unless it already listens
    /// (or gets ready to) for the same text and language.
    private func startSpeechIfNeeded() {
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

    /// The camera hears the creator while it runs (Selfie and Studio both record); with no camera (a Mac, the Simulator,
    /// no permission) Studio listens through a meter of its own, as it did before it recorded.
    private var listensThroughCamera: Bool {
        mode == .selfie || camera.status == .running
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

    private func showVoice(_ speaking: Bool, heardAt time: TimeInterval) {
        guard speaking != isVoiceActive else { return }
        isVoiceActive = speaking
        voiceMetrics.voice(speaking, heardAt: time, shownAt: clock())
    }

    /// Where the text should be: the next word to read on the guide, run a little ahead while the
    /// creator speaks (`SpeechLead`), never more than a fraction of a line past the last word
    /// recognized, and never onto the end, which only the last word heard reaches.
    private var speechTarget: Double? {
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
    private func syncSpeechPosition() {
        guard followsSpeech else { return }
        // A new place to read from: the words heard before it must not match back where they were read.
        speech.discardHeard()
        speechTracker.reset(to: scriptWords.wordIndex(
            atOffset: engine.offset, paragraphFrames: paragraphFrames, lineHeight: lineHeight, endOffset: engine.endOffset
        ))
        speechLead.reset(to: speechTracker.position)
    }
}
