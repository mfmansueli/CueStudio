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

    /// The height the editor has with no keyboard (see `measuresStableHeight`).
    @State private var stableHeight: CGFloat = 0
    /// The height of Done's question: what its content measures, plus the room under the last answer.
    @State private var doneSheetHeight: CGFloat = 520

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.forcesLowPowerMode) private var forcesLowPowerMode

    init(take: Take, services: AppServices, opening: EditorTool? = nil, onClose: @escaping (EditorOutcome) -> Void) {
        let languages = services.languages
        _viewModel = State(initialValue: QuickEditViewModel(
            take: take, takes: services.takes, library: services.library,
            editing: services.editing, drafts: services.drafts, toast: services.toast,
            editorPreferences: EditorPreferencesStore(defaults: services.defaults), prompterLook: services.preferences.prompter,
            motion: services.motion,
            speechLanguage: { languages.captionRequest(for: $0) },
            likelySpokenLanguages: { languages.likelySpokenLanguages(for: $0) },
            languageConflict: { languages.languageConflict(for: $0) }
        ))
        self.services = services
        self.opening = opening
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
                            viewModel.finish(.back)
                            onClose(.back)
                        },
                        onDone: { viewModel.askIfReadyToPost() }
                    )
                }
        }
        .modifier(CaptionTranslationRunner(viewModel: viewModel))
        .editorPhotoPicker(viewModel)
        .task {
            viewModel.creatorHandle = services.profile.profile.handle
            await viewModel.prepare()
            if let opening { viewModel.open(opening) }
        }
        .onChange(of: services.motion.completed) { viewModel.motionAnalysisDidChange() }
        .sheet(item: $viewModel.sheet) { sheet in
            switch sheet {
            case .music: AddMusicSheet(viewModel: viewModel)
            case .media: AddMediaSheet(viewModel: viewModel)
            case .transcript: TranscriptEditSheet(viewModel: viewModel)
            case .findInCaptions: CaptionFindSheet(viewModel: viewModel)
            case .clipOrder: ClipOrderSheet(viewModel: viewModel, thumbnails: services.thumbnails)
            case .done:
                EditorDoneSheet(
                    duration: DurationText.clock(viewModel.edit.editedDuration),
                    onMeasure: { doneSheetHeight = $0 + 34 },
                    onAnswer: { outcome in
                        viewModel.finish(outcome)
                        onClose(outcome)
                    }
                )
                .presentationDetents([.height(doneSheetHeight)])
                .presentationCornerRadius(Metrics.editorSheetRadius)
                .presentationBackground(Palette.surface)
                .presentationDragIndicator(.visible)
            }
        }
        .confirmationDialog(
            "This video has its own sound",
            isPresented: Binding(
                get: { viewModel.soundChoiceMediaID != nil },
                set: { if !$0 { viewModel.soundChoiceMediaID = nil } }
            ),
            titleVisibility: .visible,
            presenting: viewModel.soundChoiceMediaID
        ) { id in
            Button("Keep its sound") { viewModel.chooseSound(for: id, keeps: true) }
            Button("Mute it") { viewModel.chooseSound(for: id, keeps: false) }
        } message: { _ in
            Text("You can change it later in Media › Advanced.")
        }
        .confirmationDialog(
            "Replace your edited captions?",
            isPresented: $viewModel.confirmsCaptionReplacement,
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive) { viewModel.makeCaptions(replacingRevised: true) }
                .accessibilityIdentifier("edit.captionsReplaceButton")
            Button("Keep mine", role: .cancel) {}
        } message: {
            Text("New captions from your voice replace the lines you corrected or wrote.")
        }
        .sheet(isPresented: $viewModel.showsTranslation) {
            CaptionTranslationSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showsPasteLook) {
            PasteLookSheet(viewModel: viewModel)
        }
        .fullScreenCover(item: $viewModel.coverStudio) { studio in
            CoverStudioView(
                viewModel: studio, frameRate: Double(viewModel.take.frameRate.rawValue),
                onDone: { viewModel.finishCoverStudio($0) }, onCancel: { viewModel.cancelCoverStudio($0) }
            )
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.becameActive() } else { viewModel.pauseAndKeepDraft() }
        }
        .onDisappear { viewModel.pauseAndKeepDraft() }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: viewModel.panel)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: viewModel.stylePanelIsExpanded)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.isFullScreen)
    }

    /// The editor under the navigation bar, laid out from the height it leaves.
    private var content: some View {
        GeometryReader { proxy in
            let layout = layout(forUsableHeight: proxy.size.height)
            ZStack {
                editor(layout, width: proxy.size.width)
                if viewModel.isFullScreen {
                    fullScreenPreview(in: proxy)
                        .transition(.opacity)
                }
            }
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
                && TextStylePanel.hidesControlsWhileTyping(dynamicTypeSize)
        )
    }

    private func editor(_ layout: EditorLayout, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            QuickEditPreview(viewModel: viewModel, size: previewSize(in: CGSize(width: width, height: layout.preview)))
                .frame(width: width, height: layout.preview)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.tapOutsideVideo() }
                .overlay(alignment: .top) {
                    // Voice-over's "Show script": across the preview's whole width (wider than a vertical video), under REC.
                    if viewModel.showsNarrationScriptOverlay {
                        NarrationScriptOverlay(viewModel: viewModel, size: CGSize(width: width, height: layout.preview))
                    }
                }
                .overlay(alignment: .bottom) {
                    // At the preview's foot, clear of the toasts at its top: a reverse or an import with Cancel, and Low Power Mode.
                    VStack(spacing: 8) {
                        if let work = viewModel.work {
                            EditorWorkPill(viewModel: viewModel, work: work)
                        }
                        if viewModel.showsLowPowerNotice {
                            LowPowerNoticeBanner(viewModel: viewModel)
                                .padding(.horizontal, 16)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.bottom, 10)
                }
                .animation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.25), value: viewModel.showsLowPowerNotice)
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
                    if layout.toolbar > 0, showsPolishTip {
                        polishTip
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
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
        services.voyage.showsTip(for: .polish) && viewModel.panel == nil && viewModel.toolMenu == nil && !viewModel.isFullScreen
    }

    private var polishTip: some View {
        VoyageTipCard(
            step: .polish, symbol: VoyageStep.polish.symbol, title: VoyageStep.polish.tipTitle(), message: VoyageStep.polish.tipMessage(),
            primary: (VoyageStep.polish.tipAction(), {
                services.voyage.tipActed(.polish, at: .editor)
                viewModel.openCaptions()
            }),
            secondary: (String(localized: "Skip"), { withAnimation(.smooth(duration: 0.25)) { services.voyage.skipPolish(at: .editor) } }),
            onClose: { withAnimation(.smooth(duration: 0.25)) { services.voyage.closeTip(.polish, at: .editor) } }
        )
        .onAppear { services.voyage.tipShown(.polish, at: .editor) }
    }

    @ViewBuilder
    private func timeline(_ layout: EditorLayout) -> some View {
        if layout.showsTimeline {
            EditorTimelineView(viewModel: viewModel, heightClass: layout.heightClass)
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

    private func fullScreenPreview(in proxy: GeometryProxy) -> some View {
        let screen = CGSize(
            width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
            height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
        )
        return ZStack {
            Palette.bg
                .contentShape(Rectangle())
                .onTapGesture { viewModel.toggleFullScreen() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text("Exit full screen"))
                .accessibilityIdentifier("edit.exitFullScreen")
            QuickEditPreview(viewModel: viewModel, size: fullScreenSize(in: screen), isFullScreen: true)
            Text("Tap video to play · tap outside to exit")
                .font(.system(.footnote, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Palette.Takes.durationBadge, in: Capsule())
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 40)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
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
