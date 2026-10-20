//
//  ScriptPageView.swift
//  Cue Studio
//

import SwiftUI

/// The script page (v30 · 4.1 and 4.2): one page, no Draft | Shaped switch. The navigation bar has back, the platform and •••; the title
/// and its meter; the **state strip** (READY, DRAFT or RECORDED, the format, the cues and the next step); the words, always
/// editable, with cues as tags; and one Record button pinned at the bottom, a Liquid Glass capsule over the words that scroll
/// under it. Selecting words brings the AI bar (Apple Intelligence only); the keyboard brings the cues, in a glass bar that rides
/// on it, in Record's place. "✦ Shape" is a tool: it adds cues.
struct ScriptPageView: View {
    let viewModel: ScriptDetailViewModel
    let script: Script
    let folders: [String]
    let actions: ScriptActions
    let onRecord: () -> Void
    let onOpenTake: (Take) -> Void

    @FocusState private var focus: ScriptPageFocus?
    /// "+" on the cues bar: the name of the creator's new cue.
    @State private var isAddingCue = false
    @State private var newCue = ""
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FirstVoyageService.self) private var voyage
    @Environment(DraftLearningService.self) private var draftLearning
    /// The editor's own minimum height, kept by the words the AI writes in too.
    @ScaledMetric(relativeTo: .body) private var editorMinimumHeight = 300.0
    /// The AI has just finished: its arriving words stay over the editor, fading, while the editor fades in under them.
    @State private var isHandingOver = false
    /// The title has scrolled away under the bar: the bar says it, small, with the length under it.
    @State private var showsBarTitle = false
    /// The editor's undo history, for Undo and Redo on the cues bar over the keyboard.
    @State private var editorUndo = ScriptEditorUndo()
    /// How far the editor has taken over from the arriving words, 0 → 1 (1 at rest).
    @State private var handOver: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the words being written end: the page follows it.
    private static let writingEnd = "page.writingEnd"
    /// How far the page scrolls before the bar takes the title (about where the title has gone under it).
    private static let barTitleOffset: CGFloat = 56

    /// The words have the keyboard: what is around them steps back (`dimmedWhileTyping`).
    private var isTyping: Bool { focus == .text }
    /// Between the lines of the arriving words, as within one (`ArrivingText`'s line spacing).
    private static let arrivingLineSpacing: CGFloat = 6
    /// The crossfade from the arriving words to the editor.
    private static let handOverDuration = 0.7

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ScriptPageHeader(
                            title: $viewModel.page.title,
                            isWriting: viewModel.page.isWriting,
                            focus: $focus,
                            onSubmitTitle: { focus = .text }
                        )
                        // While the AI writes, the page is already the one it will be: the strip (with Stop), the voice question
                        // and the fact check are in their places, waiting, so nothing moves when the writing ends.
                        if let strip = viewModel.strip {
                            ScriptStateStrip(
                                strip: strip, canBeReady: !viewModel.page.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                onShape: viewModel.shape, onReady: { viewModel.setReady($0) }, onStop: stop
                            )
                            .padding(.top, 10)
                            .dimmedWhileTyping(isTyping)
                        }
                        if viewModel.showsVoicePreview, let preview = viewModel.page.voicePreview {
                            VoicePreviewStrip(
                                showing: preview.showing, isLoading: preview.isLoadingWithout,
                                onShow: viewModel.showVoice, onApprove: viewModel.approveVoice, onAdjust: viewModel.openVoiceAdjust
                            )
                            .disabled(viewModel.page.isWriting)
                            .padding(.top, 12)
                            .dimmedWhileTyping(isTyping)
                        }
                        ScriptLengthBar(zone: viewModel.zone, feelsChanges: !viewModel.page.isWriting)
                            .padding(.top, 14)
                            .dimmedWhileTyping(isTyping)
                        if viewModel.needsFactCheck {
                            FactCheckBanner(onChecked: viewModel.markFactChecked)
                                .disabled(viewModel.page.isWriting)
                                .padding(.top, 12)
                                .dimmedWhileTyping(isTyping)
                        }
                        tools
                            .padding(.top, 12)
                            .dimmedWhileTyping(isTyping)
                        editor
                            .padding(.top, 8)
                        Color.clear.frame(height: 1).id(Self.writingEnd)
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
                // Once the title has gone under the bar, the bar says it (as Notes and Mail do).
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top > Self.barTitleOffset
                } action: { _, scrolledPast in
                    withAnimation(.easeInOut(duration: 0.2)) { showsBarTitle = scrolledPast }
                }
                // A block picked in the details: the page goes there.
                .onChange(of: viewModel.readScrollTarget) { _, target in
                    guard target != nil else { return }
                    viewModel.readScrollTarget = nil
                    withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo("page.editor", anchor: .top) }
                }
                // While the AI writes, the page follows its words down, a few lines at a time and gently, so the newest are always in sight.
                .onChange(of: writingStep) { _, step in
                    guard viewModel.page.isWriting, step > 0 else { return }
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.8)) { proxy.scrollTo(Self.writingEnd, anchor: .bottom) }
                }
            }
        }
        // A bar of the scroll view's own: the words that scroll under it blur, as under the system's bars.
        .safeAreaBar(edge: .bottom, spacing: 0) { bottom }
        .toolbar { toolbarItems }
        .sheet(isPresented: $viewModel.page.showsLengthNudge) { nudge }
        .sheet(isPresented: $viewModel.page.showsVoiceAdjust) {
            VoiceAdjustSheet { adjustments, keepsInProfile in
                Task { await viewModel.rewriteVoice(adjustments: adjustments, keepsInProfile: keepsInProfile) }
            }
        }
        .alert("New cue", isPresented: $isAddingCue) {
            TextField("laugh", text: $newCue)
            Button("Cancel", role: .cancel) { focus = .text }
            Button("Add") {
                viewModel.addCue(newCue)
                focus = .text
            }
        } message: {
            Text("It goes in where the cursor is and stays on the bar for every script.")
        }
        .alert(emptySectionsMessage, isPresented: Binding(
            get: { viewModel.page.emptySectionsToConfirm != nil },
            set: { if !$0 { viewModel.page.emptySectionsToConfirm = nil } }
        )) {
            Button("Mark ready anyway") { viewModel.finish() }
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
            if phase != .active { viewModel.commitPage() }
        }
        .onChange(of: viewModel.page.title) { _, _ in viewModel.pageDidEdit() }
        .onChange(of: viewModel.page.selection) { _, selection in
            // Selecting other words is the creator moving on: the AI's words are theirs.
            if let passage = viewModel.page.passage, let selection, !selection.isEmpty, selection != passage.range { viewModel.keepPassage() }
        }
        .onDisappear { viewModel.leavePage() }
    }

    // MARK: - Bar

    /// The bar: back is the system's; the title, small, once the page's own has scrolled away; the platform ("● TikTok", opens Create for)
    /// and •••, or, while typing, the ✓ that hides the keyboard.
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(viewModel.page.title.isEmpty ? String(localized: "Untitled") : viewModel.page.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(wordsAndTime)
                    .font(CueStudioFont.hud)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.accText)
            }
            .frame(maxWidth: 210)
            .opacity(showsBarTitle ? 1 : 0)
            .accessibilityHidden(!showsBarTitle)
            .accessibilityIdentifier("page.barTitle")
        }
        if focus != nil {
            // While typing, the corner only hides the keyboard: it never changes the script's state.
            ToolbarItem(placement: .confirmationAction) {
                Button { focus = nil } label: {
                    Image(systemName: "checkmark")
                }
                .accessibilityLabel(Text("Hide keyboard"))
                .accessibilityIdentifier("page.hideKeyboard")
            }
        } else {
            pageItems
        }
    }

    /// The platform chip and •••, when not typing.
    @ToolbarContentBuilder
    private var pageItems: some ToolbarContent {
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
                    onDetails: { viewModel.sheet = .details },
                    onRemind: { viewModel.sheet = .reminder }
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

    /// Hook and Improve: the two ways into the sheets of 4.3 and 4.4 (Improve is the AI's: it goes without Apple Intelligence); then
    /// Cues, which turns the cues on or off in the teleprompter.
    private var tools: some View {
        HStack(spacing: 8) {
            Button { Task { await viewModel.openHooks() } } label: {
                HStack(spacing: 5) {
                    Image(systemName: "text.quote").font(.system(size: 12, weight: .bold))
                    Text("Hook")
                }
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
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles").font(.system(size: 12, weight: .bold))
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
            cuesToggle
            Spacer(minLength: 0)
            // Text size, as round as the tools beside it are long (it was a loose "Aa" in the corner).
            Button { viewModel.cycleTextSize() } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 34, height: 34)
                    .background(Palette.fill, in: Circle())
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Text size"))
            .accessibilityIdentifier("page.textSizeButton")
        }
    }

    /// "Cues": on (yellow, like the tags), the page draws the cue tags; off, it shows only the words. The cues stay in the script
    /// either way.
    private var cuesToggle: some View {
        @Bindable var viewModel = viewModel
        let isOn = viewModel.showsCues
        return Toggle(isOn: $viewModel.showsCues) {
            HStack(spacing: 5) {
                Image(systemName: isOn ? "eye" : "eye.slash").font(.system(size: 12, weight: .bold)).symbolSwap(value: isOn)
                Text("Cues")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isOn ? Palette.accText : Palette.ink2)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(isOn ? Palette.accSoft : Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .toggleStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Show cues"))
        .accessibilityIdentifier("page.cuesToggle")
    }

    /// Every few lines of the AI's words: the page follows them when it changes.
    private var writingStep: Int {
        guard viewModel.page.isWriting, let revealed = viewModel.page.revealed else { return 0 }
        return revealed.count / 160
    }

    /// The AI's words while it writes; then the editor, which takes over in a crossfade (the words that arrived fade out over it as their
    /// last glow goes), so the page never jumps from one to the other.
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if !viewModel.page.isWriting {
                writtenEditor
                    .opacity(handOver)
            }
            if viewModel.page.isWriting || isHandingOver {
                arrivingWords
                    .opacity(viewModel.page.isWriting ? 1 : 1 - handOver)
                    .allowsHitTesting(false)
            }
        }
        .id("page.editor")
        .onChange(of: viewModel.page.isWriting) { _, isWriting in
            guard !isWriting, !reduceMotion else { return }
            handOver = 0
            isHandingOver = true
            withAnimation(.easeInOut(duration: Self.handOverDuration)) { handOver = 1 }
            Task {
                try? await Task.sleep(for: .seconds(Self.handOverDuration + 0.05))
                isHandingOver = false
            }
        }
    }

    /// The AI's words arrive from light, one after another (4.1), drawn the way the editor that comes back will draw them: the same insets,
    /// size and cue tags, so they arrive where they stay. Once written, they are the page's text (the same words, so none arrives again).
    /// Drawn a line of the script at a time (`ArrivingLines`), so a long script never grows too tall to draw.
    private var arrivingWords: some View {
        let size = viewModel.page.textSize.points
        let lines = (viewModel.page.revealed ?? viewModel.page.text).components(separatedBy: "\n")
        return ArrivingLines(
            // An empty line keeps a line's height, as the blank line between two paragraphs does in the editor.
            lines: lines.map { ScriptTextEditor.styled($0.isEmpty ? " " : $0, passage: nil, size: size, showsCues: viewModel.showsCues) },
            size: size, lineSpacing: Self.arrivingLineSpacing
        )
            .padding(ScriptTextEditor.textInsets)
            .frame(minHeight: editorMinimumHeight, alignment: .topLeading)
            .accessibilityHidden(!viewModel.page.isWriting)
            .accessibilityIdentifier("page.writingText")
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
            showsCues: viewModel.showsCues,
            isLocked: viewModel.page.isWriting || viewModel.previewedText != nil,
            focus: $focus,
            onEdit: {
                if !viewModel.page.isWriting {
                    if viewModel.page.passage != nil { viewModel.keepPassage() }
                    viewModel.pageDidEdit()
                }
            },
            undo: editorUndo
        )
    }

    /// The bar over the selection: choosing, writing, or the AI's words waiting for Keep, Undo or Try again.
    private var barPhase: AISelectionBar.Phase? {
        if viewModel.page.isRewriting { return .writing }
        if viewModel.page.passage != nil { return .replaced }
        if viewModel.showsSelectionBar { return .choosing }
        return nil
    }

    /// The bottom: the AI bar when it has something to do, the pill while the AI writes, then the cues over the keyboard while the
    /// words have it, or the page's one Record (always there otherwise, dimmed while the AI writes).
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
                // The percentage only while the model works: once the words arrive, they are the progress.
                ScriptWritingPill(inMyVoice: viewModel.profile.writesInMyVoice, progress: viewModel.page.progress)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            if focus == .text {
                ScriptCuesBar(
                    cues: viewModel.barCues,
                    customCues: viewModel.preferences.customCues,
                    onCue: { viewModel.insertCue(named: $0) },
                    onAdd: {
                        newCue = ""
                        isAddingCue = true
                    },
                    onRemove: { viewModel.removeCue($0) },
                    undo: editorUndo
                )
            } else if let strip = viewModel.strip {
                if !viewModel.page.isWriting {
                    // The first voyage: Cue's first draft is the creator's to change, then read it once. One at a time.
                    if voyage.showsDraftTip(isCueDraft: draftLearning.isCueDraft(script.id)) {
                        draftTip
                            .padding(.bottom, 10)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if voyage.showsTip(for: .practice) {
                        practiceTip
                            .padding(.bottom, 10)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                ScriptRecordButton(title: strip.recordsAgain ? "Retake" : "Record", isPrimary: strip.recordIsPrimary, action: record)
                    .disabled(viewModel.page.isWriting)
            }
        }
        // The writing ending: the pill goes and Record wakes up as one soft movement, not a jump.
        .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: viewModel.page.isWriting)
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

    private func record() {
        focus = nil
        if viewModel.recordsNow() { onRecord() }
    }

    /// Over Record, once, after Cue's first draft: it is a starting point, the creator's to change, and Cue learns from what they keep.
    private var draftTip: some View {
        VoyageTipCard(
            step: voyage.progress.current ?? .practice, symbol: "pencil.line", title: String(localized: "A first draft. Yours to change."),
            message: String(localized: "Rewrite freely. Tap Sounds like me and Cue learns from it."),
            primary: (String(localized: "Edit"), {
                withAnimation(.smooth(duration: 0.25)) { voyage.finishDraftTip(acted: true) }
                focus = .text
            }),
            identifier: "voyage.tip.draft",
            onClose: { withAnimation(.smooth(duration: 0.25)) { voyage.finishDraftTip(acted: false) } }
        )
        .onAppear { voyage.draftTipShown() }
    }

    /// The first voyage's second step, over Record: read it out loud once in Studio (nothing is recorded).
    private var practiceTip: some View {
        VoyageTipCard(
            step: .practice, symbol: VoyageStep.practice.symbol, title: VoyageStep.practice.tipTitle(),
            message: VoyageStep.practice.tipMessage(duration: script.isEmpty ? nil : DurationText.clock(ReadTime.seconds(for: viewModel.page.text))),
            primary: (VoyageStep.practice.tipAction(), {
                voyage.tipActed(.practice, at: .page)
                focus = nil
                viewModel.commitPage()
                actions.studio(script)
            }),
            onClose: { withAnimation(.smooth(duration: 0.25)) { voyage.closeTip(.practice, at: .page) } }
        )
        .onAppear { voyage.tipShown(.practice, at: .page) }
    }
}

private extension View {
    /// While the creator types, what is around the words steps back (a third of its light, still there and still working), so the
    /// words have the page; it comes back as the keyboard goes.
    func dimmedWhileTyping(_ isTyping: Bool) -> some View {
        opacity(isTyping ? 0.3 : 1)
            .animation(.easeInOut(duration: 0.25), value: isTyping)
    }
}
