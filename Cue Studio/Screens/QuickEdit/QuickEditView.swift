//
//  QuickEditView.swift
//  Cue Studio
//

import SwiftUI

/// The editor: a vertical stack whose heights come from the usable height (`EditorLayout`), never
/// from fixed positions, so the video always shows on every iPhone.
///
/// ```
/// [Top bar]       Back · IN EDIT · AUTOSAVED · Done (asks "Is it ready to post?")
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

    /// The height the editor has with no keyboard (see `measuresStableHeight`).
    @State private var stableHeight: CGFloat = 0
    /// The height of Done's question: what its content measures, plus the room under the last answer.
    @State private var doneSheetHeight: CGFloat = 520

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(take: Take, services: AppServices, onClose: @escaping (EditorOutcome) -> Void) {
        let languages = services.languages
        _viewModel = State(initialValue: QuickEditViewModel(
            take: take, takes: services.takes, library: services.library,
            editing: services.editing, drafts: services.drafts, toast: services.toast,
            speechLanguage: { languages.captionRequest(for: $0) },
            languageConflict: { languages.languageConflict(for: $0) }
        ))
        self.services = services
        self.onClose = onClose
    }

    var body: some View {
        @Bindable var viewModel = viewModel
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
            .modifier(EditorToastHost(top: layout.topBar))
            .sheet(isPresented: sheetPanelBinding(layout)) {
                if let panel = viewModel.panel, case .sheet(let medium, let large) = layout.panelPresentation {
                    EditorPanelView(viewModel: viewModel, panel: panel)
                        .environment(\.editorHeightClass, layout.heightClass)
                        .presentationDetents([.height(medium), .height(large)])
                        .presentationBackgroundInteraction(.enabled(upThrough: .height(large)))
                        .presentationCornerRadius(Metrics.editorSheetRadius)
                        .presentationBackground(Palette.editorPanel)
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .background { measuresStableHeight }
        .modifier(CaptionTranslationRunner(viewModel: viewModel))
        .editorPhotoPicker(viewModel)
        .task {
            viewModel.creatorHandle = services.profile.profile.handle
            await viewModel.prepare()
        }
        .onChange(of: viewModel.panel) { _, panel in
            // Not tied to the panel: leaving Pauses doesn't stop it listening.
            if panel == .pauses { Task { await viewModel.analyzeIfNeeded() } }
        }
        .sheet(item: $viewModel.sheet) { sheet in
            switch sheet {
            case .music: AddMusicSheet(viewModel: viewModel)
            case .media: AddMediaSheet(viewModel: viewModel)
            case .export: QuickEditExportSheet(viewModel: viewModel, services: services)
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
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.pauseAndKeepDraft() }
        }
        .onDisappear { viewModel.pauseAndKeepDraft() }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: viewModel.panel)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.isFullScreen)
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
            panel: viewModel.panel?.size,
            panelFocusesLane: viewModel.panel?.focusedLane != nil,
            largeText: dynamicTypeSize >= .xxLarge
        )
    }

    private func editor(_ layout: EditorLayout, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            EditorTopBar(
                viewModel: viewModel,
                onBack: {
                    viewModel.finish(.back)
                    onClose(.back)
                },
                onDone: { viewModel.askIfReadyToPost() }
            )
            .frame(height: layout.topBar)
            QuickEditPreview(viewModel: viewModel, size: previewSize(in: CGSize(width: width, height: layout.preview)))
                .frame(width: width, height: layout.preview)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.tapOutsideVideo() }
            EditorPlayerBar(viewModel: viewModel)
                .frame(height: layout.playerBar)
            timeline(layout)
                .frame(height: layout.timeline)
                .clipped()
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

    @ViewBuilder
    private func timeline(_ layout: EditorLayout) -> some View {
        if layout.showsTimeline {
            EditorTimelineView(viewModel: viewModel, heightClass: layout.heightClass)
        } else {
            Color.clear
        }
    }

    /// The take's frame, as large as fits in `available`, with a little room around it.
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
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Palette.durationBadge, in: Capsule())
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
