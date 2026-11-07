//
//  QuickEditView.swift
//  Cue Studio
//

import SwiftUI

/// The editor: a vertical stack whose heights come from the usable height (`EditorLayout`), never
/// from fixed positions, so the video always shows on every iPhone.
///
/// ```
/// [Navigation]    Back · IN EDIT · AUTOSAVED · Done (asks "Is it ready to post?"), the system's bar
/// [Preview]       the take in its frame, fitted
/// [Player bar]    00:01.2 / 00:21.6 · ▶︎ · undo, redo, full screen
/// [Timeline]      the clips and the tracks under them
/// [Toolbar]       or the open panel
/// ```
///
/// Full screen shows only the video: tap it to play or pause, tap outside to come back. On the
/// smallest screens the styling panels open as a sheet whose top stays under the preview.
struct QuickEditView: View {
    @State private var viewModel: QuickEditViewModel
    private let services: AppServices
    /// How the creator left: the review they return to carries on from it (share, download…).
    let onClose: (EditorOutcome) -> Void
    /// The tool to open on once the take is ready (a notification's "Try it"); it opens, nothing runs.
    private let opening: EditorTool?
    /// The free exports' line on Done's question, for the edit as it is (the review knows what exporting it costs).
    private let exportNote: (TakeEdit) -> FreeExportLabels.Label?
    /// The review the editor opened from: Done's "Export options" line shows and changes its export options (D11), the ones its Save and
    /// Share use. Nil where nothing exports from here.
    private let review: TakeReviewViewModel?
    /// Done's "Export options", over its question.
    @State private var showsDoneExportOptions = false

    /// The height the editor has with no keyboard (see `measuresStableHeight`).
    @State private var stableHeight: CGFloat = 0
    /// How far the video has grown out of its card into full screen (`FullScreenMorph`: 0 the card, 1 full screen), where the card
    /// is on screen, and how fast a finger let it go (the spring that finishes starts at that speed).
    @State private var fullScreenShown: CGFloat = 0
    @State private var cardFrame: CGRect = .zero
    @State private var releaseSpeed: CGFloat = 0
    /// The height of Done's question: what its content measures, plus the room under the last answer.
    @State private var doneSheetHeight: CGFloat = 520

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.forcesLowPowerMode) private var forcesLowPowerMode

    init(
        take: Take, services: AppServices, opening: EditorTool? = nil, exportNote: @escaping (TakeEdit) -> FreeExportLabels.Label? = { _ in nil },
        review: TakeReviewViewModel? = nil, onClose: @escaping (EditorOutcome) -> Void
    ) {
        let languages = services.languages
        _viewModel = State(initialValue: QuickEditViewModel(
            take: take, takes: services.takes, library: services.library,
            editing: services.editing, drafts: services.drafts, toast: services.toast,
            styles: TextStyleStore(defaults: services.defaults), mediaLibrary: services.mediaLibrary, brandKits: services.brandKits,
            fonts: services.fonts, fontPacks: services.fontPacks,
            writingLanguages: { (languages.scriptLanguage, languages.interfaceLanguage) },
            editorPreferences: EditorPreferencesStore(defaults: services.defaults), prompterLook: services.preferences.prompter,
            motion: services.motion,
            speechLanguage: { languages.captionRequest(for: $0) },
            likelySpokenLanguages: { languages.likelySpokenLanguages(for: $0) },
            languageConflict: { languages.languageConflict(for: $0) }
        ))
        self.services = services
        self.opening = opening
        self.exportNote = exportNote
        self.review = review
        self.onClose = onClose
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        // A navigation stack of its own: Back, the status and Done are the system's bar, in its Liquid Glass.
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                // Full screen is only the video.
                .toolbarVisibility(viewModel.isFullScreen ? .hidden : .visible, for: .navigationBar)
                .toolbar {
                    EditorTopBar(
                        viewModel: viewModel,
                        onBack: {
                            if let left = viewModel.finish(.back) { onClose(left) }
                        },
                        onDone: { viewModel.askIfReadyToPost() }
                    )
                }
        }
        .environment(\.brandColors, viewModel.edit.brandKit?.colors ?? [])
        .modifier(CaptionTranslationRunner(viewModel: viewModel))
        .editorPhotoPicker(viewModel)
        .task {
            viewModel.creatorHandle = services.profile.profile.handle
            await viewModel.prepare()
            if let opening { viewModel.open(opening) }
        }
        .onChange(of: services.motion.completed) { viewModel.motionAnalysisDidChange() }
        .onChange(of: services.fontPacks.generation) { viewModel.fontPacksChanged() }
        .sheet(item: $viewModel.sheet) { sheet in
            switch sheet {
            case .music: AddMusicSheet(viewModel: viewModel)
            case .soundEffects: AddMusicSheet(viewModel: viewModel, effectsOnly: true)
            case .textToSpeech: TextToSpeechSheet(viewModel: viewModel)
            case .media: AddMediaSheet(viewModel: viewModel)
            case .transcript: TranscriptEditSheet(viewModel: viewModel)
            case .findInCaptions: CaptionFindSheet(viewModel: viewModel)
            case .clipOrder: ClipOrderSheet(viewModel: viewModel, thumbnails: services.thumbnails)
            case .done:
                EditorDoneSheet(
                    duration: DurationText.clock(viewModel.edit.editedDuration),
                    exportNote: exportNote(viewModel.edit),
                    fontNote: viewModel.fontsNotReady.map(EditorDoneFontNote.text),
                    exportOptions: review.map { $0.outputSummary(for: viewModel.edit) },
                    onExportOptions: { showsDoneExportOptions = true },
                    onMeasure: { doneSheetHeight = $0 + 34 },
                    onAnswer: { outcome in
                        if let left = viewModel.finish(outcome) { onClose(left) }
                    }
                )
                .sheet(isPresented: $showsDoneExportOptions) {
                    if let review {
                        ShareExportOptions(review: review, edit: viewModel.edit)
                            .presentationDetents([.medium])
                            .presentationBackground(Palette.sheetNight)
                    }
                }
                .presentationDetents([.height(doneSheetHeight)])
                .presentationCornerRadius(Metrics.editorSheetRadius)
                .presentationBackground(Palette.surface)
                .presentationDragIndicator(.visible)
            }
        }
        .background {
            // Replace with a longer video: which part fills the place.
            Color.clear.sheet(item: Binding(get: { viewModel.session.partChoice }, set: { viewModel.session.partChoice = $0 })) { choice in
                MediaPartSheet(viewModel: viewModel, choice: choice)
            }
        }
        .background {
            // ✦ Smart › Brand: which parts of a kit go on, and a kit made or changed.
            Color.clear.sheet(item: Bindable(viewModel.brand).kitToApply) { kit in
                BrandKitApplySheet(viewModel: viewModel, kit: kit)
                    .environment(\.brandColors, viewModel.edit.brandKit?.colors ?? [])
            }
            Color.clear.sheet(item: Bindable(viewModel.brand).kitBeingEdited) { kit in
                BrandKitEditorSheet(viewModel: viewModel, kit: kit)
            }
        }
        .confirmationDialog(
            "This video has its own sound",
            isPresented: Binding(
                get: { viewModel.overlays.soundChoiceMediaID != nil },
                set: { if !$0 { viewModel.overlays.soundChoiceMediaID = nil } }
            ),
            titleVisibility: .visible,
            presenting: viewModel.overlays.soundChoiceMediaID
        ) { id in
            Button("Keep its sound") { viewModel.overlays.chooseSound(for: id, keeps: true) }
            Button("Mute it") { viewModel.overlays.chooseSound(for: id, keeps: false) }
        } message: { _ in
            Text("You can change it later in Volume, on the media’s bar.")
        }
        .confirmationDialog(
            "A Blur area may not cover what it hides",
            isPresented: Bindable(viewModel).showsBlurCheck,
            titleVisibility: .visible
        ) {
            Button("Go there") { viewModel.reviewUncheckedBlur() }
                .accessibilityIdentifier("edit.blurCheck.review")
            Button("Continue anyway") { viewModel.continueDespiteUncheckedBlur() }
                .accessibilityIdentifier("edit.blurCheck.continue")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("For \(DurationText.tenths(viewModel.uncheckedBlurDuration)) Cue couldn't confirm it covers what it hides. One frame is enough to show someone.")
        }
        .confirmationDialog(
            "Replace your edited captions?",
            isPresented: Bindable(viewModel.captions).confirmsCaptionReplacement,
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive) { viewModel.captions.makeCaptions(replacingRevised: true) }
                .accessibilityIdentifier("edit.captionsReplaceButton")
            Button("Keep mine", role: .cancel) {}
        } message: {
            Text("New captions from your voice replace the lines you corrected or wrote.")
        }
        .confirmationDialog(
            "Delete all \(viewModel.edit.captions.count) caption lines?",
            isPresented: Bindable(viewModel.captions).confirmsDeletingAll,
            titleVisibility: .visible
        ) {
            Button("Delete all", role: .destructive) { viewModel.captions.deleteAllCaptions() }
                .accessibilityIdentifier("edit.captionsDeleteAllConfirm")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Undo brings them back.")
        }
        .sheet(isPresented: Bindable(viewModel.captions).showsTranslation) {
            CaptionTranslationSheet(viewModel: viewModel)
        }
        .sheet(isPresented: Bindable(viewModel.look).showsPasteLook) {
            PasteLookSheet(viewModel: viewModel)
        }
        .fullScreenCover(item: Bindable(viewModel.cover).coverStudio) { studio in
            CoverStudioView(
                viewModel: studio, frameRate: Double(viewModel.take.frameRate.rawValue),
                onDone: { viewModel.cover.finishCoverStudio($0) }, onCancel: { viewModel.cover.cancelCoverStudio($0) }
            )
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: viewModel.becameActive()
            case .inactive: viewModel.becameInactive()
            default: viewModel.pauseAndKeepDraft()
            }
        }
        .onAppear { viewModel.leaveScreen = { onClose($0) } }
        .onDisappear { viewModel.pauseAndKeepDraft() }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: viewModel.panel)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: viewModel.stylePanelIsExpanded)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.isFullScreen)
        // A track coming or going, or every track out or away: the video gives or takes back its room smoothly.
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: viewModel.timelineLanes)
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: viewModel.tracks.isExpanded)
        // The editor's type is one size on every iPhone, its sheets and the app's controls in it too (a slider, a chip).
        .environment(\.typeFollowsScreenWidth, false)
    }

    /// The editor under the navigation bar, laid out from the height it leaves.
    private var content: some View {
        GeometryReader { proxy in
            let layout = layout(forUsableHeight: proxy.size.height)
            ZStack {
                editor(layout, width: proxy.size.width)
                fullScreenLayer(in: proxy)
            }
            .onChange(of: viewModel.isFullScreen) { _, isFullScreen in settleFullScreen(isFullScreen, lands: true) }
            .overlay {
                if viewModel.source == .loading {
                    EditorOpeningOverlay().transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: viewModel.source == .loading)
            .modifier(EditorToastHost())
            .sheet(isPresented: sheetPanelBinding(layout)) {
                if let panel = viewModel.panel, case .sheet(let medium, let large) = layout.panelPresentation {
                    EditorPanelView(viewModel: viewModel, panel: panel)
                        .environment(\.editorHeightClass, layout.heightClass)
                        // Expanding the panel is the sheet's taller height, and dragging the sheet expands it.
                        .presentationDetents([.height(medium), .height(large)], selection: sheetDetentBinding(medium: medium, large: large))
                        .presentationBackgroundInteraction(.enabled(upThrough: .height(large)))
                        .presentationCornerRadius(Metrics.editorSheetRadius)
                        .presentationBackground(Palette.Editor.panel)
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .background { measuresStableHeight }
    }

    // MARK: - Layout

    /// The editor's height as if the keyboard were never up. The editor itself lays out in what the
    /// keyboard leaves (the system's own avoidance, the only one at work: nothing here moves anything
    /// by hand), but how it is laid out (class, tracks, panel as a panel or as a sheet) must not
    /// depend on the keyboard, or opening it would change the layout under the field being typed in.
    private var measuresStableHeight: some View {
        GeometryReader { _ in
            Color.clear
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { stableHeight = $0 }
        }
        .ignoresSafeArea(.keyboard)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func layout(forUsableHeight height: CGFloat) -> EditorLayout {
        EditorLayout(
            usableHeight: height,
            stableHeight: stableHeight > 0 ? stableHeight : nil,
            panel: viewModel.openPanelSize,
            panelFocusesLane: viewModel.panel?.focusedLane != nil,
            largeText: dynamicTypeSize >= .xxLarge,
            panelIsExpanded: viewModel.stylePanelIsExpanded && viewModel.panel?.isExpandable == true,
            typesInHeaderField: viewModel.panel == .textStyle && viewModel.selectedText?.graphic == nil
                && TextStylePanel.hidesControlsWhileTyping(dynamicTypeSize),
            timelineLanes: viewModel.timelineLanes, collapsesTimeline: !viewModel.tracks.isExpanded,
            timelineReveal: viewModel.panel == nil ? viewModel.timelineReveal : nil
        )
    }

    private func editor(_ layout: EditorLayout, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            QuickEditPreview(
                viewModel: viewModel, size: previewSize(in: CGSize(width: width, height: layout.preview)),
                showsFullScreenArrow: fullScreenShown == 0 && !viewModel.isFullScreen && viewModel.swipesFullScreen
            )
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cardFrame = $0 }
                .frame(width: width, height: layout.preview)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.tapOutsideVideo() }
                // Swiping down on the video, or beside it, grows it into full screen under the finger.
                .modifier(fullScreenSwipe(isFullScreen: false))
                .overlay(alignment: .top) {
                    // Voice-over's "Show script": across the preview's whole width (wider than a vertical video), under REC.
                    if viewModel.showsNarrationScriptOverlay {
                        NarrationScriptOverlay(viewModel: viewModel, size: CGSize(width: width, height: layout.preview))
                    }
                }
                .overlay(alignment: .bottom) {
                    // At the preview's foot, clear of the toasts at its top: a reverse or an import with Cancel, media no longer on
                    // this iPhone, and Low Power Mode.
                    VStack(spacing: 8) {
                        if let work = viewModel.work {
                            EditorWorkPill(viewModel: viewModel, work: work)
                        }
                        if let motion = viewModel.motionPendingLabel {
                            MotionPendingPill(label: motion)
                                .transition(.opacity)
                        }
                        if viewModel.showsMissingMediaNotice {
                            MissingMediaNotice(viewModel: viewModel)
                                .padding(.horizontal, 16)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                        }
                        if viewModel.showsLowPowerNotice {
                            LowPowerNoticeBanner(viewModel: viewModel)
                                .padding(.horizontal, 16)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    // Above the full screen arrow at the video's foot (`PreviewFullScreenArrow`).
                    .padding(.bottom, viewModel.swipesFullScreen ? 40 : 10)
                }
                .animation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.25), value: viewModel.showsLowPowerNotice)
                .animation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.25), value: viewModel.showsMissingMediaNotice)
                .task {
                    viewModel.lowPowerModeChanged(isLowPower)
                    for await _ in NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange) {
                        viewModel.lowPowerModeChanged(isLowPower)
                    }
                }
            EditorPlayerBar(viewModel: viewModel)
                .frame(height: layout.playerBar)
            timeline(layout)
                .frame(height: layout.timeline)
                .clipped()
                .overlay(alignment: .bottom) {
                    // The first voyage's Polish step, over the timeline's lower part and right above the tools it talks about.
                    VoyageInPlaceTip(step: .polish, place: .editor, isAllowed: layout.toolbar > 0 && showsPolishTip) { isDone in
                        polishTip(isDone: isDone)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
            if layout.toolbar > 0 {
                EditorToolbar(viewModel: viewModel, heightClass: layout.heightClass)
                    .frame(height: layout.toolbar)
                    .transition(.opacity)
            }
            if layout.panel > 0, let panel = viewModel.panel {
                EditorPanelView(viewModel: viewModel, panel: panel)
                    .environment(\.editorHeightClass, layout.heightClass)
                    .frame(height: layout.panel)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .disabled(viewModel.isFullScreen)
    }

    // MARK: - The first voyage

    private var showsPolishTip: Bool {
        viewModel.panel == nil && viewModel.toolMenu == nil && !viewModel.isFullScreen
    }

    private func polishTip(isDone: Bool) -> some View {
        VoyageTipCard(
            step: .polish, title: VoyageStep.polish.tipTitle(), message: VoyageStep.polish.tipMessage(),
            primary: (VoyageStep.polish.tipAction(), {
                services.voyage.tipActed(.polish, at: .editor)
                viewModel.openCaptions()
            }),
            secondary: (String(localized: "Skip"), { withAnimation(.smooth(duration: 0.25)) { services.voyage.skipPolish(at: .editor) } }),
            isDone: isDone,
            onClose: { withAnimation(.smooth(duration: 0.25)) { services.voyage.closeTip(.polish, at: .editor) } }
        )
    }

    @ViewBuilder
    private func timeline(_ layout: EditorLayout) -> some View {
        if layout.showsTimeline {
            EditorTimelineView(
                viewModel: viewModel, heightClass: layout.heightClass, openLaneHeight: layout.openLaneHeight,
                revealSpan: layout.openTimeline - layout.collapsedTimeline
            )
        } else {
            Color.clear
        }
    }

    /// The take's frame, as large as fits in `available`, with a little room around it.
    /// Low Power Mode, as the system says (or on, in UI tests that ask for it).
    private var isLowPower: Bool {
        forcesLowPowerMode || ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private func previewSize(in available: CGSize) -> CGSize {
        let aspect = viewModel.edit.aspect.widthOverHeight
        let maxWidth = max(0, available.width - 16)
        let maxHeight = max(0, available.height - 6)
        var width = maxHeight * aspect
        var height = maxHeight
        if width > maxWidth {
            width = maxWidth
            height = maxWidth / aspect
        }
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    // MARK: - Full screen

    /// Full screen, growing out of the video's card and shrinking back into it (`FullScreenLayer`). A swipe up anywhere on it
    /// brings the editor back.
    private func fullScreenLayer(in proxy: GeometryProxy) -> some View {
        let screen = CGSize(
            width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
            height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
        )
        let picture = fullScreenSize(in: screen)
        let full = CGRect(
            x: (screen.width - picture.width) / 2, y: (screen.height - picture.height) / 2, width: picture.width, height: picture.height
        )
        let morph = FullScreenMorph(
            card: cardFrame, full: full, screen: screen, cardRadius: Metrics.editorPreviewRadius, moves: !reduceMotion, shown: fullScreenShown
        )
        return FullScreenLayer(viewModel: viewModel, morph: morph, pictureSize: picture, swipe: fullScreenSwipe(isFullScreen: true))
    }

    /// The swipe that grows the video into full screen (down, in the editor) or back into its card (up, in full screen): the video
    /// follows the finger, and once let go a spring finishes the change, or takes it back, from the finger's speed.
    private func fullScreenSwipe(isFullScreen: Bool) -> FullScreenSwipeGesture {
        FullScreenSwipeGesture(
            isFullScreen: isFullScreen,
            isEnabled: viewModel.swipesFullScreen && viewModel.isFullScreen == isFullScreen,
            yields: { viewModel.overlays.draggedOverlay != nil || viewModel.overlays.lockedUnderFinger != nil },
            moved: { follow in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { fullScreenShown = isFullScreen ? 1 - follow : follow }
            },
            ended: { changes, speed in
                if changes {
                    Haptics.light()
                    releaseSpeed = speed
                    viewModel.toggleFullScreen()
                } else {
                    releaseSpeed = -speed
                    settleFullScreen(isFullScreen, lands: false)
                }
            }
        )
    }

    /// The video on to full screen or back into its card, with a spring that starts at the speed a finger let it go with (a touch
    /// of bounce on the way in), and a soft tap when it `lands` somewhere new. With Reduce Motion, full screen fades.
    private func settleFullScreen(_ isFullScreen: Bool, lands: Bool) {
        let target: CGFloat = isFullScreen ? 1 : 0
        let remaining = abs(target - fullScreenShown)
        let velocity = remaining > 0.02 ? min(max(releaseSpeed / remaining, 0), 8) : 0
        releaseSpeed = 0
        let animation: Animation = reduceMotion
            ? .easeInOut(duration: 0.25)
            : .interpolatingSpring(duration: isFullScreen ? 0.5 : 0.42, bounce: isFullScreen ? 0.12 : 0, initialVelocity: velocity)
        withAnimation(animation, completionCriteria: .logicallyComplete) {
            fullScreenShown = target
        } completion: {
            if lands, !reduceMotion { Haptics.soft() }
        }
    }

    private func fullScreenSize(in screen: CGSize) -> CGSize {
        let aspect = viewModel.edit.aspect.widthOverHeight
        var width = screen.height * aspect
        var height = screen.height
        if width > screen.width {
            width = screen.width
            height = screen.width / aspect
        }
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    private func sheetDetentBinding(medium: CGFloat, large: CGFloat) -> Binding<PresentationDetent> {
        Binding(
            get: { viewModel.stylePanelIsExpanded ? .height(large) : .height(medium) },
            set: { viewModel.stylePanelIsExpanded = $0 == .height(large) }
        )
    }

    private func sheetPanelBinding(_ layout: EditorLayout) -> Binding<Bool> {
        Binding(
            get: {
                guard viewModel.panel != nil, case .sheet = layout.panelPresentation else { return false }
                return true
            },
            set: { if !$0 { viewModel.panel = nil } }
        )
    }
}
