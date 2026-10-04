//
//  ScriptPageView.swift
//  Cue Studio
//

import SwiftUI

/// The script page (v29 · 4.1 and 4.2): one page, no Draft | Shaped switch. A bar with back, the platform and •••; the title
/// and its meter; the **state strip** (READY, DRAFT or RECORDED, the format, the cues and the next step); the words, always
/// editable, with cues as tags; and one Record button at the bottom. Selecting words brings the AI bar (Apple Intelligence
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

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            ScriptPageTopBar(
                platform: script.platform,
                onBack: onBack,
                onPlatform: { viewModel.sheet = .destination },
                menu: {
                    ScriptPageMenu(
                        script: script, folders: folders, actions: actions,
                        hasAI: viewModel.isLanguageModelAvailable,
                        onImprove: { viewModel.sheet = .improve },
                        onVersions: { viewModel.startEditing() },
                        onDetails: { viewModel.sheet = .details }
                    )
                }
            )
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ScriptPageHeader(
                            title: $viewModel.page.title,
                            wordsAndTime: wordsAndTime,
                            isWriting: viewModel.page.isWriting,
                            writesInMyVoice: viewModel.profile.writesInMyVoice,
                            focus: $focus,
                            onStop: viewModel.stopWriting,
                            onSubmitTitle: { focus = .text }
                        )
                        if let strip = viewModel.strip, !viewModel.page.isWriting {
                            ScriptStateStrip(strip: strip, onShape: viewModel.shape, onDone: done)
                                .padding(.top, 12)
                        }
                        if viewModel.showsVoicePreview, let preview = viewModel.page.voicePreview {
                            VoicePreviewStrip(
                                showing: preview.showing, isLoading: preview.isLoadingWithout,
                                onShow: viewModel.showVoice, onApprove: viewModel.approveVoice, onAdjust: viewModel.openVoiceAdjust
                            )
                            .padding(.top, 12)
                        }
                        ScriptLengthBar(zone: viewModel.zone)
                            .padding(.top, 14)
                        if viewModel.needsFactCheck {
                            FactCheckBanner(onChecked: viewModel.markFactChecked)
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

    // MARK: - Pieces

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

    private var editor: some View {
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
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
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
