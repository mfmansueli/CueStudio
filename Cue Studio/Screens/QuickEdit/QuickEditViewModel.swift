//
//  QuickEditViewModel.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Quick edit of one take. The edit is a recipe (`TakeEdit`) on top of the recording, which is never changed, and the player
/// (`EditPlayback`) plays it and owns the playhead. Every decision the creator makes on the edit is an undo step of its
/// document (`EditDocument`); what listening finds is laid on without one. A gesture or a sheet that changes something many
/// times in a row is one undo step (`beginChange` / `endChange`). A draft is kept while editing and when leaving with Cancel;
/// Done saves the edit on the take.
///
/// The editor coordinates its parts (`EditorPart`), each with its own state, working on the edit through the session
/// (`EditorSession`) the editor hosts (`EditorHost`): `CaptionsViewModel`, `CoverViewModel`, `LookViewModel`, `AudioViewModel`,
/// `OverlaysViewModel`, `BlurViewModel` and `ClipsViewModel`. What is the editor's own: what is picked and which panel, sheet or menu is open
/// (`show(_:)`, `pick(_:)`), what one part's change means for another (a panel left, the edit changed, the editor closed),
/// what the preview plays, the timeline that draws every part's tracks and its gestures (`+Timeline`, `+Layers`), the
/// toolbar, Undo, and leaving with the draft.
@MainActor
@Observable
final class QuickEditViewModel: EditorHost, EditorPart {
    /// Whether the recording could be opened.
    enum Source: Equatable {
        case loading, ready, unavailable
    }

    // MARK: Editor
    /// The panel open under the timeline, in place of the toolbar. Its ✓ closes it; changes show
    /// live in the preview. Setting it is `show(_:)`.
    var panel: EditorPanel? {
        get { shownPanel }
        set { show(newValue) }
    }
    /// The one thing picked on the timeline or in the preview (a cut included); its tools replace the toolbar's. Setting it
    /// is `pick(_:)`.
    var selection: EditorSelection? {
        get { picked }
        set { pick(newValue) }
    }
    private var shownPanel: EditorPanel?
    private var picked: EditorSelection?
    /// The clip a clip panel picked when it opened with nothing picked (`EditorPanel.pinsClip`): the panel lets go of it when it
    /// closes, unless the creator picked something else meanwhile.
    @ObservationIgnored private var panelPick: EditorSelection?
    /// A track's own toolbar (Text, Audio, Media), opened from the main one or by tapping the track, with nothing selected. Its
    /// track becomes the timeline's current one.
    var toolMenu: EditorToolMenu? {
        didSet {
            if let toolMenu, toolMenu != oldValue { bringTrack(toolMenu.lanes) }
        }
    }
    /// The timeline's current track and whether every track is out (`TimelineTrackChoice`); the current one is kept for the take.
    var tracks = TimelineTrackChoice() {
        didSet {
            if tracks.current != oldValue.current { editorPreferences.setTimelineLane(tracks.current, forTake: take.id) }
        }
    }
    /// A finger dragging the timeline up or down, or ▾ settling: how far out every track is (`EditorLayout.timelineReveal`,
    /// `TimelineGeometry.Input.reveal`); nil while the timeline rests.
    var timelineReveal: CGFloat?
    /// The open panel's tab (Text style and Caption style).
    var panelTab: EditorPanelTab = .presets
    /// The open panel's "Advanced" section is expanded.
    var showsAdvanced = false
    /// A styling sheet stepped aside on the iPhone SE so the timeline can be reached (`tuckPanel`, canvas 2 R10 §7.3): the panel
    /// stays open (its item, tab, style and the playhead with it) and the toolbar's place says how to bring it back.
    var panelIsTucked = false
    /// Each panel's tab and Advanced as they were left, per item where the panel is an item's (`PanelMemory`, canvas 2 R7).
    var panelMemory = PanelMemory()
    /// The item the open panel's tab and Advanced belong to.
    var panelStateItem: UUID?
    /// The Templates panel's tab: the one its button on a bar asked for (`openTemplates(on:)`).
    var templatesSection: TemplatesPanelSection = .templates
    /// Which whole-video tools already said, on which kind of item's bar, that they change the whole video (once each while the
    /// editor is open, `tap(_:)`).
    @ObservationIgnored var scopeNoticesSaid: [EditorToolbarContext: Set<String>] = [:]
    /// Where each toolbar was scrolled, so the main tools come back where they were left (`EditorToolbarScrollMemory`).
    @ObservationIgnored var toolbarScroll = EditorToolbarScrollMemory()
    /// The preview fills the screen: tap the video to play or pause, outside to come back.
    var isFullScreen = false
    /// The sheet over the editor: Export, Add music, Add photo or video.
    var sheet: EditorSheet? {
        didSet {
            audio.sheetChanged(to: sheet)
        }
    }
    /// The timeline's zoom (44 points per second at 1), from 0.35 to 5.
    var timelineZoom: CGFloat = 1
    /// The timeline handle being dragged.
    var handleDrag: TimelineHandleDrag? {
        didSet {
            if case .clip? = handleDrag?.target { clips.holdsClipHandle = true } else { clips.holdsClipHandle = false }
        }
    }
    /// Where the dragged handle last stuck, so the haptic plays once per snap.
    @ObservationIgnored var lastHandleSnap: TimeInterval?
    /// A caption line's handle reached its limit in this gesture: the haptic taps once (`CaptionStretchRoom`).
    @ObservationIgnored var stretchLimitNoticed = false
    /// The styling panels (Text style, Caption style) are expanded: the video gets as small as it
    /// ever gets so the controls have room. Kept while the editor is open.
    var stylePanelIsExpanded = false
    /// The edit and its undo steps (`EditDocument`): the edit changes only there, and this hears each change.
    let document: EditDocument
    private(set) var source: Source = .loading

    /// The Low Power Mode notice over the preview (`QuickEditViewModel+LowPower`).
    var showsLowPowerNotice = false
    /// The edit's sounds together go over full scale (`measureMix`): Volume says the preview may distort where the video won't.
    var mixTooLoud = false
    /// Done was tapped while a Blur area may not cover what it hides somewhere: asked first (`+Blur`).
    var showsBlurCheck = false
    /// The creator went on despite it: not asked again until the edit changes.
    @ObservationIgnored var blurCheckAccepted = false
    /// The draft kept as Cue went to the background couldn't be written (a full iPhone): tried again on the way back.
    @ObservationIgnored private var draftNotKept = false
    /// A narration was being recorded as Cue left the screen: it stopped there (what was recorded is a clip), said on the way back.
    @ObservationIgnored private var narrationStoppedAway = false
    /// Files the edit names that are no longer on this iPhone, looked for at opening and when the edit's files change.
    private(set) var missingMedia: Set<String> = []
    /// Taking `missingMedia` out leaves a video (else only replacing the clip helps).
    private(set) var canRemoveMissingMedia = false
    private var missingMediaNoticeHidden = false
    /// Whether the edit on screen is on disk, for the top bar (`EditorDraftKeeper`).
    let draftKeeper: EditorDraftKeeper
    /// Leaving was asked while the edit couldn't be kept anywhere: the editor stayed and said so; asked again, it leaves.
    @ObservationIgnored private var warnedNotKept = false
    /// How the screen goes away when the creator leaves from a toast ("Leave anyway"), set by the screen.
    @ObservationIgnored var leaveScreen: (EditorOutcome) -> Void = { _ in }
    /// The creator's handle, for the "@handle" graphic and the cover's series (set by the screen).
    var creatorHandle: String {
        get { session.creatorHandle }
        set { session.creatorHandle = newValue }
    }

    let take: Take
    let player: EditPlayback
    let editing: TakeEditing
    let library: ScriptLibraryService
    let toast: ToastService
    /// Quick edit's own switches, kept between edits.
    let editorPreferences: EditorPreferencesStoring
    /// The library of takes (a montage adds others from it).
    let takes: TakeLibraryService
    private let drafts: QuickEditDraftStoring
    /// What the editor's parts work through: the document, the player, the jobs and the toasts, and this editor as their host.
    let session: EditorSession
    /// Captions: made, corrected, picked, styled, translated and moved on the preview (`CaptionsViewModel`).
    let captions: CaptionsViewModel
    /// The cover: Cover Studio over the editor, and the cover drawn for the timeline's block (`CoverViewModel`).
    let cover: CoverViewModel
    /// The picture: Adjust, Auto, Filters, Background, Format, Stabilize, Copy look (`LookViewModel`).
    let look: LookViewModel
    /// The video track: clips, speed, transitions, montage, reverse, replace, Pauses and Clean Up, Edit by text
    /// (`ClipsViewModel`).
    let clips: ClipsViewModel
    /// The sound: Studio Voice, music and sound effects, beats, voice-overs, a clip's sound pulled out (`AudioViewModel`).
    let audio: AudioViewModel
    /// What lies on the video: texts and graphics, photos and videos, their motion and keyframes, Track, type styles
    /// (`OverlaysViewModel`).
    let overlays: OverlaysViewModel
    /// The creator's own things: the media library, brand kits and imported fonts (`BrandViewModel`).
    let brand: BrandViewModel
    /// Blur area: faces, plates and names hidden, followed and checked (`BlurViewModel`).
    let blur: BlurViewModel
    /// Where a failure the creator saw is written down (`noteFailure`): Console and Crashlytics; tests read it.
    /// A template on the video while its sheet is open (`QuickEditViewModel+Templates`).
    var templateTrial: TemplateTrial?
    @ObservationIgnored var reportFailure: (EditorFailureReport) -> Void = { $0.send() }
    /// Everything the editor started and waits for (`EditorJobs`): Auto, captions, Track, the cover, a short preview, the
    /// sound compared, the draft, beats, Clean Up and tools' work. Closing cancels it all.
    @ObservationIgnored let jobs: EditorJobs

    init(
        take: Take, takes: TakeLibraryService, library: ScriptLibraryService, editing: TakeEditing,
        drafts: QuickEditDraftStoring, toast: ToastService, player: EditPlayback? = nil,
        mediaImporter: EditMediaImporting? = nil, recorder: VoiceOverRecording? = nil, styles: TextStyleStoring? = nil,
        myWords: MyWordsStoring? = nil, mediaLibrary: MediaLibraryStore? = nil, brandKits: BrandKitStore? = nil, fonts: CustomFontStore? = nil,
        fontPacks: FontPackStore? = nil, writingLanguages: @escaping () -> (script: CueLanguage?, interface: CueLanguage?) = { (nil, nil) },
        editorPreferences: EditorPreferencesStoring? = nil, prompterLook: PrompterSettings = PrompterSettings(),
        coverPictures: CoverPicturing? = nil, soundPreviews: SoundPreviewing? = nil,
        translations: TranslationAvailabilityChecking = AppleTranslationAvailability(), motion: MotionAnalysisService? = nil,
        tracker: ObjectTracking = ObjectTracker(), faceFinder: FaceFinding = FaceFinder(),
        speechLanguage: @escaping (Script?) -> SpeechLanguageRequest = SpeechLanguageRequest.script,
        likelySpokenLanguages: @escaping (Script?) -> [CueLanguage] = { _ in [] },
        languageConflict: @escaping (Script?) -> SpeechLanguageConflict? = { _ in nil }
    ) {
        self.take = take
        let styles = styles ?? TextStyleStore()
        let mediaImporter = mediaImporter ?? EditMediaImporter()
        let preferences = editorPreferences ?? EditorPreferencesStore()
        self.editorPreferences = preferences
        self.takes = takes
        self.library = library
        self.editing = editing
        self.drafts = drafts
        draftKeeper = EditorDraftKeeper(store: drafts, takeID: take.id)
        self.toast = toast
        document = EditDocument(Self.startingEdit(for: take))
        let player = player ?? QuickEditPlayer(videoURL: takes.videoURL(for: take), editing: editing)
        self.player = player
        let jobs = EditorJobs()
        self.jobs = jobs
        session = EditorSession(
            document: document, player: player, jobs: jobs, toast: toast, take: take, videoURL: takes.videoURL(for: take),
            importer: mediaImporter
        )
        let takeID = take.id
        session.keepRememberedLook = { [weak preferences] look in preferences?.setRememberedLook(look, forTake: takeID) }
        captions = CaptionsViewModel(
            session: session, editing: editing, takes: takes, library: library, styles: styles, myWords: myWords ?? MyWordsStore(),
            translations: translations,
            speechLanguage: speechLanguage, likelySpokenLanguages: likelySpokenLanguages, languageConflict: languageConflict
        )
        // Without the app's stores (tests, previews): ones of their own in a temporary folder, never the creator's.
        let scratch = URL.temporaryDirectory.appending(path: "EditorAssets-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fontPacks = fontPacks ?? FontPackStore(source: OfflineFontPackSource(), directory: scratch.appending(path: "FontPacks"))
        let fonts = fonts ?? CustomFontStore(
            repository: LocalCustomFontRepository(directory: scratch.appending(path: "Fonts")), directory: scratch.appending(path: "Fonts")
        )
        cover = CoverViewModel(
            session: session, editing: editing, pictures: coverPictures ?? CoverPictureService(), importer: mediaImporter,
            styles: styles, fontPacks: fontPacks, customFonts: fonts, writingLanguages: writingLanguages
        )
        look = LookViewModel(session: session, editing: editing, motion: motion, preferences: preferences)
        clips = ClipsViewModel(session: session, editing: editing, takes: takes, library: library, speechLanguage: speechLanguage)
        overlays = OverlaysViewModel(
            session: session, styles: styles, library: library, tracker: tracker, faces: faceFinder
        )
        blur = BlurViewModel(session: session, tracker: tracker, faces: faceFinder)
        audio = AudioViewModel(
            session: session, editing: editing, importer: mediaImporter, recorder: recorder ?? VoiceOverRecorder(),
            editorPreferences: preferences, prompterLook: prompterLook, soundPreviews: soundPreviews ?? SoundPreviewPlayer()
        )
        brand = BrandViewModel(
            session: session,
            library: mediaLibrary ?? MediaLibraryStore(
                repository: LocalMediaLibraryRepository(directory: scratch.appending(path: "Library")), directory: scratch.appending(path: "Library")
            ),
            kits: brandKits ?? BrandKitStore(
                repository: LocalBrandKitRepository(directory: scratch.appending(path: "Kits")), directory: scratch.appending(path: "Kits")
            ),
            fonts: fonts, fontPacks: fontPacks, styles: styles, writingLanguages: writingLanguages
        )
        session.host = self
        self.player.playingStopped = { [weak self] in self?.audio.playingStopped() }
        document.onChange = { [weak self] previous in self?.editChanged(from: previous) }
        if let lane = preferences.timelineLane(forTake: take.id) { tracks.current = lane }
    }

    /// Opens the recording, picks up a draft left behind and starts the player.
    func prepare() async {
        guard source == .loading else { return }
        TextEffectRenderer.prepareInBackground()
        let duration: TimeInterval
        do {
            duration = try await editing.sourceDuration(ofVideoAt: videoURL)
        } catch {
            noteFailure(error, "open")
            source = .unavailable
            return
        }
        if let rate = await editing.frameRate(ofVideoAt: videoURL) { session.frameRate = FrameGrid(rate: rate).rate }
        look.recordingUprightSize = await EditFraming.shape(of: videoURL)?.uprightSize
        guard !isClosed else { return }
        // The file's own length wins over the take's saved one; a draft left behind comes back with its undo steps.
        var playhead: TimeInterval = 0
        let reading = drafts.reading(for: take.id)
        let restored = document.open(sourceDuration: duration, draft: reading.draft)
        if restored, let draft = reading.draft { playhead = draft.playhead }
        // What Copy and Paste look remember comes back with the project, without being a change to it.
        if let remembered = editorPreferences.rememberedLook(forTake: take.id) {
            document.remember { remembered.apply(to: &$0) }
        }
        switch reading {
        case .unreadable:
            // The take's own edit opens; the draft's file is kept aside before a new draft can be written over it.
            toast.show(String(localized: "Couldn't open your draft · A copy is kept on this iPhone"), kind: .problem)
        case .draft(_, partial: true) where restored:
            toast.show(String(localized: "Draft restored · Some parts couldn't be read"), kind: .problem)
        case .draft where restored:
            toast.show(String(localized: "Draft restored"))
        case .draft, .none:
            break
        }
        let partial = if case .draft(_, partial: true) = reading { restored } else { false }
        draftKeeper.opened(onDraft: restored && !partial)
        sayMissingMedia()
        clips.opened()
        source = .ready
        // A video edited for the first time opens in the creator's style, once: undone, it stays as filmed next time too.
        if take.edit == nil, !restored, case .none = reading, !editorPreferences.newVideoKitOffered(forTake: take.id), brand.wearNewVideoKit() {
            editorPreferences.markNewVideoKitOffered(forTake: take.id)
        }
        // What was read in part is written again as it now is (the file as it was is kept), so the chip says Saved truly.
        if partial {
            draftKeeper.changed(hasChanges: hasUnsavedChanges)
            scheduleDraftSave()
        }
        player.show(edit)
        player.seek(to: playhead)
        cover.drawCover()
        // The script libraries' faces the video's words need, if they aren't here yet.
        brand.requestFontPacks()
        // Only an edit that uses Follow face or Stabilize has its recordings analyzed now; the others when Format or
        // Stabilize opens (an hour of video is a lot to analyze for nothing).
        look.requestMotionAnalysisIfNeeded()
        audio.findBeatsIfNeeded()
    }

    /// Files the edit names that are gone from the iPhone, said as it opens (never a silent black stretch), with Remove as one undo step
    /// when that fixes it; else Replace on the clip does (the review won't export it as it is).
    /// Looks again for the files the edit names that are no longer on this iPhone (`MissingMediaNotice`, over the preview).
    private func sayMissingMedia() {
        missingMedia = edit.missingMedia()
        canRemoveMissingMedia = !missingMedia.isEmpty && edit.canDropMedia(missingMedia)
    }

    func removeMissingMedia(_ missing: Set<String>) {
        document.changeEdit { $0 = $0.withoutMedia(missing) }
    }

    /// ✕ on the notice: hidden for this visit (the review still asks before exporting past what is missing).
    func hideMissingMediaNotice() {
        missingMediaNoticeHidden = true
    }

    var showsMissingMediaNotice: Bool { !missingMedia.isEmpty && !missingMediaNoticeHidden && !isFullScreen }

    /// The edit changed: what was picked and is gone is let go, and the preview, the draft and the cover follow.
    private func editChanged(from previous: TakeEdit) {
        // Edit by text's picked words, and the lines timed to the edit.
        clips.editChanged(from: previous)
        captions.editChanged(from: previous)
        guard source == .ready else { return }
        if let id = selectedSegmentID, edit.timeline.segment(id: id) == nil { selectedSegmentID = nil }
        if let id = selectedTextID, !edit.texts.contains(where: { $0.id == id }) { selectedTextID = nil }
        if let id = selectedMediaID, !edit.media.contains(where: { $0.id == id }) { selectedMediaID = nil }
        if let id = selectedCaptionID, !edit.captions.contains(where: { $0.id == id }) { selectedCaptionID = nil }
        if let id = reviewedVoiceOverID, !edit.voiceOvers.contains(where: { $0.id == id }) { reviewedVoiceOverID = nil }
        if let id = selectedMusicID, !edit.music.contains(where: { $0.id == id }) { selectedMusicID = nil }
        if let id = selectedBlurID, !edit.blurRegions.contains(where: { $0.id == id }) { selectedBlurID = nil }
        // A file put back by Undo, or taken out: whether something is missing is looked for again.
        if edit.mediaFileNames != previous.mediaFileNames { sayMissingMedia() }
        overlays.editChanged()
        blur.editChanged()
        blur.growWithClips(from: previous)
        blurCheckAccepted = false
        if selectedJoinID != nil, selectedJoinIndex == nil { selectedJoinID = nil }
        // A new treatment isn't what was being compared.
        audio.editChanged()
        // A change is no longer what was being compared; a recording now played is analyzed when it needs to be.
        look.editChanged()
        clips.updateCurveSoundStepping()
        player.show(playedEdit)
        cover.editChanged()
        brand.requestFontPacks()
        draftKeeper.changed(hasChanges: hasUnsavedChanges)
        scheduleDraftSave()
    }

    /// A script's face arrived or went (`FontPackStore.generation`): the preview and the cover draw their words again.
    func fontPacksChanged() {
        guard source == .ready else { return }
        player.redraw()
        cover.drawCover()
    }

    // MARK: - Panels and picking

    /// Opens `next` under the timeline (nil closes the panel). Leaving a panel ends what went on in it: its undo step, a
    /// narration being recorded, a comparison, Auto measuring, the lines picked in Captions, and Transition's cut.
    func show(_ next: EditorPanel?) {
        guard next != shownPanel else { return }
        leavePanel(for: next, endingChange: true)
    }

    /// Picks `next` (nil lets go). The Text or Audio menu gives way to it; a cut opens its Transition panel; a panel that
    /// works on the picked item closes when it can't work on `next`, ending its own control's undo step. Picking never ends a
    /// gesture's: one that picks (or lets go of what it removed) keeps its one step. An item picked anywhere (the timeline, the
    /// preview, a tool) brings its track under the video.
    func pick(_ next: EditorSelection?) {
        guard next != picked else { return }
        // Another photo or video, or none: a support starts on its own area (a tap on the main video's says so after, `pickArea`).
        if next?.mediaID != picked?.mediaID { overlays.selectedArea = .support }
        picked = next
        // ◐ on a music clip compares that clip only.
        if let compared = audio.comparedDuckingID, next?.musicID != compared { audio.endDuckingComparison() }
        // ◐ in Voice effects compares the picked voice only.
        if audio.comparedVoiceEffect != nil { audio.endVoiceEffectComparison() }
        if let lane = next?.lane, lane != .main { bringTrack([lane]) }
        // Picked by the creator: no longer the panel's to let go of.
        if next != panelPick { panelPick = nil }
        if next != nil { toolMenu = nil }
        if next?.joinID != nil {
            if shownPanel != .transition {
                leavePanel(for: nil, endingChange: true)
                leavePanel(for: .transition, endingChange: true)
            }
        } else if let panel = shownPanel, look.followsSelection(panel), !(next.map { look.accepts($0, in: panel) } ?? false) {
            leavePanel(for: nil, endingChange: false)
        }
        panelPickChanged()
    }

    /// The one way the panel changes: what the panel left behind ends, in this order, once.
    private func leavePanel(for next: EditorPanel?, endingChange: Bool) {
        let previous = shownPanel
        guard next != previous else { return }
        shownPanel = next
        panelIsTucked = false
        if let lane = next?.focusedLane { bringTrack([lane]) }
        pinClip(for: next)
        swapPanelState(from: previous, to: next)
        audio.panelChanged(from: previous)
        // Auto, Compare, the recordings' analysis for Format and Stabilize, a clip's scope.
        look.panelChanged(to: next)
        // Opening another panel ends any change; a pick that closes it ends only the panel's own (its control may never say it
        // let go), never a gesture's that picks or lets go of what it removed.
        if endingChange { endAllChanges() } else { endPanelChange() }
        audio.stopRecordingIfNeeded()
        // A cut is picked only while its Transition panel is open.
        if previous == .transition, picked?.joinID != nil { picked = nil }
        clips.panelChanged(to: next)
        // Crop shows the clip's whole picture while it is open.
        if previous == .clipCrop || next == .clipCrop { showPlayedEdit() }
        captions.panelChanged(to: next)
        blur.panelChanged(to: next)
        if next != .mask { overlays.comparesWithoutMask = false }
    }

    /// A clip panel opened with nothing picked picks the clip under the playhead, and lets go of it when it closes (or gives way
    /// to a panel that isn't a clip's); a clip the creator picked stays picked. The Text or Audio menu stays under it.
    private func pinClip(for next: EditorPanel?) {
        if let pin = panelPick {
            guard !(next.map { $0.pinsClip && look.accepts(pin, in: $0) } ?? false) else { return }
            panelPick = nil
            if picked == pin { picked = nil }
        } else if picked == nil, next?.pinsClip == true, let clip = targetClip {
            picked = .clip(clip.id)
            panelPick = picked
        }
    }

    // MARK: - Reading

    var videoURL: URL { takes.videoURL(for: take) }

    /// The recording is open and the preview can play.
    var isReady: Bool { source == .ready && player.state != .failed }

    /// "00:04.1": where the playhead is. It reads the player's clock, so only the small views that
    /// show it redraw while the video plays.
    var currentTimeLabel: String {
        DurationText.editor(player.currentTime)
    }

    /// "00:11.0": the edit's length.
    var durationLabel: String {
        DurationText.editor(edit.editedDuration)
    }

    /// "00:04.1 / 00:11.0"
    var timeLabel: String { currentTimeLabel + " / " + durationLabel }

    var canUndo: Bool { document.canUndo && !audio.isRecordingVoiceOver }
    var canRedo: Bool { document.canRedo && !audio.isRecordingVoiceOver }
    var hasUnsavedChanges: Bool { document.hasUnsavedChanges }

    /// What the editor opens on before a draft: the take's finished edit, or a new one fitted to it.
    static func startingEdit(for take: Take) -> TakeEdit {
        var edit = take.edit ?? TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
        if take.edit == nil { edit.captionCollection?.safeMargins = CaptionsViewModel.captionSafeMargins(for: take, aspect: take.aspect) }
        CaptionSafeArea.repairMargins(of: &edit, for: take)
        edit.captions = edit.captions.map(CaptionRevision.withoutContinuation)
        return edit
    }

    // MARK: - Playback

    func togglePlayback() {
        guard isReady else { return }
        takePlayhead()
        player.togglePlayback()
    }

    /// The creator takes the playhead (Play, a drag, a handle, a frame step, a jump to a cut): a part still playing to show a
    /// change (a text effect's Preview, a pause listened to) ends there and never pulls the playhead back to where it began.
    func takePlayhead() {
        session.endPreview()
        if clips.listeningID != nil { clips.listeningID = nil }
    }

    /// VoiceOver: moves the playhead by `seconds`.
    func nudgePlayhead(by seconds: TimeInterval) {
        guard isReady else { return }
        takePlayhead()
        player.pause()
        player.seek(to: player.currentTime + seconds)
    }

    /// Try again, under a preview that couldn't be built: the edit is built from scratch.
    func retryPreview() {
        guard source == .ready else { return }
        player.retry()
    }

    /// What the preview plays: the edit (without what a finger is dragging; with the picked clip's whole picture while Crop is
    /// open), while ◐ is held the picture as recorded (Adjust, Filters, Background) or without Skin (Skin), a music clip without
    /// lowering under the voice (Volume), a voice without its effect (Voice effects), or while comparing the sound, the take's
    /// sound untreated at the same loudness.
    var playedEdit: TakeEdit {
        let pictured = look.comparesPicture ? edit.withoutPictureLook() : look.comparesSkin ? edit.withoutSkin() : edit
        let compared = audio.withoutComparedVoiceEffect(audio.withoutComparedDucking(pictured))
        let looked = clips.showingWholePicture(in: compared)
        let unmasked = blur.withoutComparedBlur(overlays.withoutComparedMask(looked))
        let shown = overlays.hidingDraggedOverlay(in: unmasked)
        guard audio.comparesOriginal, let volume = audio.originalVolume else { return shown }
        var played = shown
        played.audioVersion = VoiceProcessing.currentVersion
        played.voiceEnhancement = .off
        played.noiseReduction = .off
        played.volume = volume
        return played
    }

    /// What the preview plays changed (a comparison started or ended): the player shows it again.
    func showPlayedEdit() {
        player.show(playedEdit)
    }

    /// A recording's motion analysis is ready: the preview is drawn again when what it plays reads one.
    /// "Measuring the shake · 40%" over the preview while Stabilize or Follow face waits for its analysis and the panel that says so
    /// (Stabilize, Format) is closed: until then the clip plays as filmed, which would otherwise look like the tool did nothing.
    var motionPendingLabel: String? {
        guard source == .ready, !isFullScreen, panel != .stabilize, panel != .crop, EditedComposition.usesMotion(edit) else { return nil }
        let shake = edit.timeline.segments.contains { $0.stabilization != nil }
        return MotionAnalysisNote.text(for: look.motionAnalysisStatus, purpose: shake ? .shake : .face)
    }

    func motionAnalysisDidChange() {
        // A Blur area's handles read Stabilize's and Follow face's paths from the analyses.
        blur.placements.removeAll()
        guard source == .ready, EditedComposition.usesMotion(playedEdit) else { return }
        player.redraw()
    }

    /// Cue is in front again: a preview that failed meanwhile (iOS resets its media services in the background) is built
    /// again on its own.
    func becameActive() {
        if narrationStoppedAway {
            narrationStoppedAway = false
            toast.show(String(localized: "Voice-over stopped when you left Cue · What you recorded is kept"), kind: .problem)
        }
        if draftNotKept {
            draftNotKept = !saveDraft()
            if draftNotKept { toast.show(notSavedMessage, kind: .problem) }
        }
        guard source == .ready, player.state == .failed else { return }
        player.retry()
    }

    // MARK: - Screen

    /// The preview fills the screen (or comes back); what was picked and the open panel are let go.
    func toggleFullScreen() {
        selection = nil
        toolMenu = nil
        panel = nil
        isFullScreen.toggle()
    }

    /// The arrow at the video's foot and the swipe it stands for: while the editor shows the video with nothing open over it
    /// (and in full screen), not while a voice-over records.
    var swipesFullScreen: Bool {
        isReady && panel == nil && !audio.isRecordingVoiceOver
    }

    /// A tap on the preview beside what's laid on the video: lets go of a picked text, caption or
    /// photo.
    func tapOutsideVideo() {
        switch selection {
        case .text, .caption, .media: selection = nil
        default: break
        }
    }

    /// Old takes use a matching version only; a newer script is never an alignment reference.
    var captionScript: Script? { take.captionScript(current: library.script(id: take.scriptID)) }

    // MARK: - Leaving

    /// Saves the edit on the take (its new length, marked Edited) when anything changed.
    /// - Returns: true when the edit is on the take, false when it couldn't be and stays a draft, nil when it couldn't be kept anywhere
    ///   and the editor stays open (said once, with Leave anyway).
    @discardableResult
    func done() -> Bool? {
        endAllChanges()
        audio.stopRecordingIfNeeded()
        // Reversed videos nothing plays any more (a clip reversed and put back) were kept for undo; they go now.
        var saved = edit
        let played = Set(edit.timeline.segments.compactMap(\.sourceID))
        saved.sources.removeAll { $0.reversal != nil && !played.contains($0.id) }
        if source == .ready, hasUnsavedChanges {
            do {
                try takes.applyEdit(saved, to: take.id)
            } catch {
                noteFailure(error, "save")
                // Not on disk: the edit stays a draft (and its files with it) that Edit opens again; when even that can't be written,
                // the editor stays open and says so.
                guard saveDraft(forced: true) || leavesUnkept(.notYet) else { return nil }
                close(keepingDraft: true)
                toast.show(draftKeeper.isFailing ? notSavedMessage : String(localized: "Couldn't save the edits · Kept as a draft"), kind: .problem)
                return false
            }
            toast.show(String(localized: "Edits saved to this take"))
        }
        removeUnusedImports(keeping: saved.mediaFileNames)
        close(keepingDraft: false)
        return true
    }

    /// Why the edit couldn't be written, said so the creator can act: a full iPhone, or try again (anything else isn't blamed on space).
    private var notSavedMessage: String {
        if case .failed(.other) = draftKeeper.state { return String(localized: "Couldn't save the edits · Try again") }
        return String(localized: "Couldn't save the edits · Free up space on this iPhone")
    }

    /// The edit couldn't be kept anywhere and the creator asked to leave. The first time the editor stays and says so, with Leave
    /// anyway; asked again (or Leave anyway), it goes, keeping whatever draft was last written.
    /// - Returns: true when it leaves now.
    private func leavesUnkept(_ outcome: EditorOutcome) -> Bool {
        if warnedNotKept { return true }
        warnedNotKept = true
        toast.show(
            notSavedMessage, kind: .problem,
            action: ToastAction(title: String(localized: "Leave anyway")) { [weak self] in self?.leaveAnyway(outcome) }
        )
        return false
    }

    private func leaveAnyway(_ outcome: EditorOutcome) {
        guard !isClosed else { return }
        close(keepingDraft: true)
        leaveScreen(outcome)
    }

    /// Done: pauses and asks "Is it ready to post?" (`EditorDoneSheet`); the answer is `finish(_:)`.
    func askIfReadyToPost() {
        guard isReady else { return }
        endAllChanges()
        player.pause()
        // Work that changes the edit when it ends (a Blur area still being tracked hasn't covered anything yet): the video
        // would go out without it.
        if let work = pendingWork {
            toast.show(work.waitMessage, kind: .problem)
            return
        }
        // A Blur area that may not cover what it hides: one frame is enough to show someone.
        if !blurCheckAccepted, uncheckedBlurDuration > 0 {
            showsBlurCheck = true
            return
        }
        selection = nil
        panel = nil
        sheet = .done
    }

    /// Work started here that changes the edit when it ends, the first that runs (`EditorPendingWork`).
    var pendingWork: EditorPendingWork? {
        if captions.captionState.isWorking { return .captions }
        if captions.translationState.isWorking { return .translation }
        if overlays.isTracking { return .tracking }
        if blur.isFollowing { return .blurArea }
        if jobs.isRunning(where: Self.makesAClip) { return .clip }
        if jobs.isRunning(.auto) { return .auto }
        return nil
    }

    private nonisolated static func makesAClip(_ kind: EditorJobs.Kind) -> Bool {
        switch kind {
        case .reverse, .importing, .tool: true
        default: false
        }
    }

    /// Leaves the editor the way the creator answered: the edit is saved on the take (share, download,
    /// ready later), kept as a draft the video stays in edit with (not yet), or kept as a draft
    /// without asking (back).
    /// - Returns: what the review carries on with (an edit that couldn't be saved on the take is a draft, never shared or saved as it
    ///   was), or nil when the editor stays open because the edit couldn't be kept anywhere.
    @discardableResult
    func finish(_ outcome: EditorOutcome) -> EditorOutcome? {
        sheet = nil
        switch outcome {
        case .share, .download, .ready:
            guard let saved = done() else { return nil }
            return saved ? outcome : .notYet
        case .notYet: return keepForLater() ? outcome : nil
        case .back: return cancel() ? outcome : nil
        }
    }

    /// "Not yet, I'll come back": the draft stays even if nothing changed, so the video is in edit.
    /// - Returns: false when the editor stays open (the draft couldn't be written).
    private func keepForLater() -> Bool {
        endAllChanges()
        // A narration being recorded is kept with the draft.
        audio.stopRecordingIfNeeded()
        let kept = saveDraft(forced: true)
        guard kept || leavesUnkept(.notYet) else { return false }
        close(keepingDraft: true)
        if !kept { toast.show(notSavedMessage, kind: .problem) }
        return true
    }

    /// Leaves without saving on the take. Changes stay in a draft that Edit picks up again; the take is as it was. A draft
    /// left from before stays too while the video is still opening or couldn't be opened: nothing here replaced it.
    /// - Returns: false when the editor stays open (the changes couldn't be written).
    @discardableResult
    func cancel() -> Bool {
        endAllChanges()
        // A narration being recorded is kept with the draft, like every other change.
        audio.stopRecordingIfNeeded()
        guard source == .ready else {
            removeUnusedImports(keeping: document.original.mediaFileNames)
            close(keepingDraft: true)
            return true
        }
        guard hasUnsavedChanges else {
            removeUnusedImports(keeping: document.original.mediaFileNames)
            close(keepingDraft: false)
            return true
        }
        let kept = saveDraft()
        guard kept || leavesUnkept(.back) else { return false }
        // Read before closing stops it: what didn't finish is said, the rest is in the draft.
        let stopped = pendingWork
        close(keepingDraft: true)
        if !kept {
            toast.show(notSavedMessage, kind: .problem)
        } else if let stopped {
            toast.show(stopped.stoppedMessage, kind: .problem)
        } else {
            toast.show(String(localized: "Draft saved"))
        }
        return true
    }

    /// Control Center, a notification pulled down, the app switcher on its way: Cue is still on screen and the microphone still
    /// its own, so a narration being recorded goes on (and the video under it); anything else pauses. The draft is written now,
    /// in case iOS ends Cue next (a call taking the microphone is said by the recorder).
    func becameInactive() {
        if audio.recorder.isRecording {
            guard !saveDraft() else { return }
            draftNotKept = true
            toast.show(notSavedMessage, kind: .problem)
            return
        }
        pauseAndKeepDraft()
    }

    /// Leaving the app or the screen without Done or Cancel: the draft keeps everything. A narration being recorded stops there
    /// and becomes its clip, said when Cue is back.
    func pauseAndKeepDraft() {
        if audio.recorder.isRecording, !isClosed { narrationStoppedAway = true }
        audio.stopRecordingIfNeeded()
        player.pause()
        // Not written: said now (an edit iOS may end in the background shouldn't go unnoticed) and tried again on the way back.
        guard !saveDraft() else { return }
        draftNotKept = true
        toast.show(notSavedMessage, kind: .problem)
    }

    /// Files copied in during this visit that nothing kept names: the take's saved edit (and the
    /// one it had) still point at theirs.
    private func removeUnusedImports(keeping names: Set<String>) {
        let unused = importedFiles.subtracting(names).subtracting(document.original.mediaFileNames)
        importedFiles = []
        EditMediaFiles.remove(unused)
    }

    /// Nothing started here outlives the editor: every job is cancelled, and what a slow one hands back after is dropped
    /// (its ticket is no longer current; work awaited elsewhere checks `isClosed`).
    private func close(keepingDraft: Bool) {
        look.cancelAuto()
        overlays.trackingProgress = nil
        jobs.close()
        captions.translationRequest = nil
        if !keepingDraft { drafts.discard(takeID: take.id) }
        player.stop()
    }

    /// Writes down a failure the creator was told about (`EditorFailureReport`): what was being done, the error and the
    /// edit's size. A cancellation isn't one.
    func noteFailure(_ error: any Error, _ operation: String) {
        guard let report = EditorFailureReport.make(error, operation: operation, edit: edit) else { return }
        reportFailure(report)
    }

    /// Starts work a tool waits for (a freeze frame, a reverse, a sound pulled out): leaving the editor cancels it.
    func startJob(_ work: @escaping @MainActor () async -> Void) {
        jobs.startTool(work)
    }

    // MARK: - Draft

    private func scheduleDraftSave(after delay: Duration = .milliseconds(600)) {
        jobs.start(.draft) { [weak self] _ in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.autosaveDraft()
        }
    }

    /// The draft as the editor has it now.
    private var currentDraft: QuickEditDraft {
        QuickEditDraft(takeID: take.id, edit: edit, playhead: player.currentTime, history: document.draftHistory, savedAt: .now)
    }

    /// 600 ms after a change: the draft written off the main thread (`EditorDraftKeeper.saveSoon`), or dropped when nothing is
    /// changed any more. A write that fails is said once and tried again every few seconds until one works.
    private func autosaveDraft() {
        guard source == .ready, !isClosed else { return }
        if hasUnsavedChanges {
            draftKeeper.saveSoon(currentDraft) { [weak self] failure, first in self?.autosaveFailed(failure, first: first) }
        } else {
            draftKeeper.discard()
        }
    }

    private func autosaveFailed(_ failure: QuickEditDraftSaveFailure, first: Bool) {
        guard !isClosed else { return }
        if first {
            noteFailure(failure, "draft")
            toast.show(
                failure == .noSpace
                    ? String(localized: "Couldn't save the edits · Free up space on this iPhone")
                    : String(localized: "Couldn't save the edits · Cue keeps trying"),
                kind: .problem
            )
        }
        scheduleDraftSave(after: Self.draftRetryDelay)
    }

    /// How long a failed autosave waits before it tries again.
    static let draftRetryDelay: Duration = .seconds(5)

    /// Keeps the edit, the playhead and the undo steps now (on leaving, or the app going away), or drops the draft when
    /// nothing changed. False when the draft couldn't be written (the store logs why).
    @discardableResult
    func saveDraft(forced: Bool = false) -> Bool {
        guard source == .ready, !isClosed else { return true }
        if hasUnsavedChanges || forced {
            if let error = draftKeeper.saveNow(currentDraft) {
                noteFailure(error, "draft")
                return false
            }
            warnedNotKept = false
        } else {
            draftKeeper.discard()
        }
        return true
    }
}
