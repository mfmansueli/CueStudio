//
//  ScriptPageView.swift
//  Cue Studio
//

import SwiftUI

/// The script page (v30 · 4.1 and 4.2): one page, no Draft | Shaped switch. The navigation bar has back, the platform and •••; the title
/// and its meter; the **state strip** (READY, DRAFT or RECORDED, the format, the cues and the next step); the words, always
/// editable, with cues as tags; and one Record button at the bottom. The bar above is the system's: its back button, the platform
/// and •••. Selecting words brings the AI bar (Apple Intelligence
/// only); the keyboard brings the cues bar. "✦ Shape" is a tool: it adds cues.
struct ScriptPageView: View {
    let viewModel: ScriptDetailViewModel
    let script: Script
    let folders: [String]
    let actions: ScriptActions
    let onBack: () -> Void
    let onRecord: () -> Void
    let onOpenTake: (Take) -> Void

    @FocusState private var focus: ScriptPageFocus?
    @Environment(\.scenePhase) private var scenePhase
    /// The editor's own minimum height, kept by the words the AI writes in too.
    @ScaledMetric(relativeTo: .body) private var editorMinimumHeight = 300.0

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ScriptPageHeader(
                            title: $viewModel.page.title,
                            wordsAndTime: wordsAndTime,
                            isWriting: viewModel.page.isWriting,
                            focus: $focus,
                            onSubmitTitle: { focus = .text }
                        )
                        // While the AI writes, the page is already the one it will be: the strip (with Stop), the voice question
                        // and the fact check are in their places, waiting, so nothing moves when the writing ends.
                        if let strip = viewModel.strip {
                            ScriptStateStrip(
                                strip: strip, onShape: viewModel.shape, onDone: done,
                                onStop: stop
                            )
                            .padding(.top, 12)
                        }
                        if viewModel.showsVoicePreview, let preview = viewModel.page.voicePreview {
                            VoicePreviewStrip(
                                showing: preview.showing, isLoading: preview.isLoadingWithout,
                                onShow: viewModel.showVoice, onApprove: viewModel.approveVoice, onAdjust: viewModel.openVoiceAdjust
                            )
                            .disabled(viewModel.page.isWriting)
                            .padding(.top, 12)
                        }
                        ScriptLengthBar(zone: viewModel.zone)
                            .padding(.top, 14)
                        if viewModel.needsFactCheck {
                            FactCheckBanner(onChecked: viewModel.markFactChecked)
                                .disabled(viewModel.page.isWriting)
                                .padding(.top, 12)
                        }
                        tools
                            .padding(.top, 12)
                        editor
                            .padding(.top, 8)
                        ScriptTipsView(viewModel: viewModel)
                            .padding(.top, 16)
                        if !viewModel.scriptTakes.isEmpty {
                            ScriptTakesStrip(takes: viewModel.scriptTakes, version: script.version, onOpen: onOpenTake)
                                .padding(.top, 24)
                        }
                    }
                    .padding(.horizontal, Metrics.textGutter)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                // A block picked in the details: the page goes there.
                .onChange(of: viewModel.readScrollTarget) { _, target in
                    guard target != nil else { return }
                    viewModel.readScrollTarget = nil
                    withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo("page.editor", anchor: .top) }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottom }
        .toolbar { toolbarItems }
        .sheet(isPresented: $viewModel.page.showsLengthNudge) { nudge }
        .sheet(isPresented: $viewModel.page.showsVoiceAdjust) {
            VoiceAdjustSheet { adjustments, keepsInProfile in
                Task { await viewModel.rewriteVoice(adjustments: adjustments, keepsInProfile: keepsInProfile) }
            }
        }
        .alert(emptySectionsMessage, isPresented: Binding(
            get: { viewModel.page.emptySectionsToConfirm != nil },
            set: { if !$0 { viewModel.page.emptySectionsToConfirm = nil } }
        )) {
            Button("Done anyway") { viewModel.finish() }
            Button("Keep writing", role: .cancel) { focus = .text }
        }
        .animation(.smooth(duration: 0.2), value: barPhase)
        .onAppear {
            if viewModel.page.focusesTitle {
                viewModel.page.focusesTitle = false
                focus = .title
            } else if viewModel.page.focusesText {
                viewModel.page.focusesText = false
                focus = .text
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                viewModel.commitPage()
                viewModel.leaveAsDraftIfEdited()
            }
        }
        .onChange(of: viewModel.page.title) { _, _ in viewModel.pageDidEdit() }
        .onChange(of: viewModel.page.selection) { _, selection in
            // Selecting other words is the creator moving on: the AI's words are theirs.
            if let passage = viewModel.page.passage, let selection, !selection.isEmpty, selection != passage.range { viewModel.keepPassage() }
        }
        .onDisappear { viewModel.leavePage() }
    }

    // MARK: - Bar

    /// The platform ("● TikTok", opens Create for) and ••• in the bar's glass; back is the system's.
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { viewModel.sheet = .destination } label: {
                HStack(spacing: 6) {
                    PlatformDot(color: script.platform.tint)
                    Text(script.platform.label).font(.footnote.weight(.semibold))
                }
            }
            .accessibilityLabel(Text("Create for"))
            .accessibilityValue(Text(script.platform.label))
            .accessibilityIdentifier("page.platformChip")
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ScriptPageMenu(
                    script: script, folders: folders, actions: actions,
                    hasAI: viewModel.isLanguageModelAvailable,
                    onImprove: { viewModel.sheet = .improve },
                    onVersions: { viewModel.startEditing() },
                    onDetails: { viewModel.sheet = .details }
                )
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel(Text("More"))
            .accessibilityIdentifier("page.menuButton")
        }
    }

    // MARK: - Pieces

    /// Stop, while the AI writes.
    private var stop: (() -> Void)? {
        guard viewModel.page.isWriting else { return nil }
        return { viewModel.stopWriting() }
    }

    /// "113 WORDS · ~0:45"
    private var wordsAndTime: String {
        let zone = viewModel.zone
        return String(localized: "\(zone.words) words · ~\(DurationText.clock(zone.seconds))")
    }

    /// Hook and Improve: the two ways into the sheets of 4.3 and 4.4 (Improve is the AI's: it goes without Apple Intelligence).
    private var tools: some View {
        HStack(spacing: 8) {
            Button { Task { await viewModel.openHooks() } } label: {
                Text("Hook")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Palette.fill, in: Capsule())
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("page.hookButton")
            if viewModel.isLanguageModelAvailable {
                Button { viewModel.sheet = .improve } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                        Text("Improve")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.aiTextStrong)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Palette.aiFill, in: Capsule())
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("page.improveButton")
            }
            Spacer(minLength: 0)
            Button { viewModel.cycleTextSize() } label: {
                Text("Aa")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Text size"))
            .accessibilityIdentifier("page.textSizeButton")
        }
    }

    @ViewBuilder
    private var editor: some View {
        if viewModel.page.isWriting {
            // The AI's words arrive from light, one after another (4.1), drawn the way the editor that comes back will draw them:
            // the same insets, size and cue tags, so they arrive where they stay.
            let size = viewModel.page.textSize.points
            ArrivingText(styled: ScriptTextEditor.styled(viewModel.page.revealed ?? "", passage: nil, size: size), size: size)
                .padding(ScriptTextEditor.textInsets)
                .frame(minHeight: editorMinimumHeight, alignment: .topLeading)
                .id("page.editor")
                .accessibilityIdentifier("page.writingText")
        } else {
            writtenEditor
        }
    }

    private var writtenEditor: some View {
        @Bindable var viewModel = viewModel
        return ScriptTextEditor(
            text: Binding(
                get: { viewModel.page.revealed ?? viewModel.previewedText ?? viewModel.page.text },
                set: { if !viewModel.page.isWriting { viewModel.page.text = $0 } }
            ),
            selection: $viewModel.page.selection,
            passage: viewModel.page.passage?.range,
            textSize: viewModel.page.textSize,
            isLocked: viewModel.page.isWriting || viewModel.previewedText != nil,
            focus: $focus,
            onEdit: {
                if !viewModel.page.isWriting {
                    if viewModel.page.passage != nil { viewModel.keepPassage() }
                    viewModel.pageDidEdit()
                }
            }
        )
        .id("page.editor")
    }

    /// The bar over the selection: choosing, writing, or the AI's words waiting for Keep, Undo or Try again.
    private var barPhase: AISelectionBar.Phase? {
        if viewModel.page.isRewriting { return .writing }
        if viewModel.page.passage != nil { return .replaced }
        if viewModel.showsSelectionBar { return .choosing }
        return nil
    }

    /// The bottom: the AI bar when it has something to do, then the cues above the keyboard or the page's one Record.
    private var bottom: some View {
        VStack(spacing: 8) {
            if let phase = barPhase, focus != .title {
                AISelectionBar(
                    phase: phase,
                    onAction: { action in Task { await viewModel.rewriteSelection(action) } },
                    onKeep: viewModel.keepPassage,
                    onUndo: viewModel.undoPassage,
                    onRetry: { Task { await viewModel.retryPassage() } }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if viewModel.page.isWriting {
                ScriptWritingPill(inMyVoice: viewModel.profile.writesInMyVoice)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            if focus == .text {
                ScriptCuesBar(onCue: viewModel.insertCue)
            } else if focus != .title, !viewModel.page.isWriting, let strip = viewModel.strip {
                ScriptRecordBar(
                    title: strip.recordsAgain ? "Retake" : "Record", isPrimary: strip.recordIsPrimary, action: record
                )
                .background(Palette.bg)
            }
        }
    }

    private var emptySectionsMessage: String {
        let count = viewModel.page.emptySectionsToConfirm ?? 0
        return count == 1 ? String(localized: "1 section is still empty.") : String(localized: "\(count) sections are still empty.")
    }

    private var nudge: some View {
        LengthNudgeSheet(
            platform: script.platform,
            seconds: viewModel.zone.seconds,
            idealUpper: viewModel.preset.idealRange.upperBound,
            onRecordAnyway: {
                viewModel.page.showsLengthNudge = false
                viewModel.commitPage()
                onRecord()
            },
            offersShorter: viewModel.isLanguageModelAvailable,
            onShorter: {
                viewModel.page.showsLengthNudge = false
                Task { await viewModel.run(.fitToTime) }
            }
        )
        .presentationDetents([.height(300)])
    }

    /// Done: a draft or a script being edited becomes ready; one that is ready and unchanged simply goes back.
    private func done() {
        focus = nil
        if viewModel.strip?.state == .ready, !viewModel.page.isEdited {
            onBack()
        } else {
            viewModel.done()
        }
    }

    private func record() {
        focus = nil
        if viewModel.recordsNow() { onRecord() }
    }
}
