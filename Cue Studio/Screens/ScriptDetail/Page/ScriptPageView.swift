//
//  ScriptPageView.swift
//  Cue Studio
//

import SwiftUI

/// The script page (v26): one page with **Draft | Shaped**. Draft is free writing; Shaped is the
/// same words as sections with timing, on demand. The AI writes into the page in violet. The old
/// block editor is one step away, in ••• › Versions & options.
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
                mode: Binding(get: { viewModel.page.mode }, set: { viewModel.setMode($0) }),
                isModeLocked: viewModel.page.isWriting,
                onBack: onBack,
                onPlatform: { viewModel.sheet = .destination },
                onRecord: record,
                menu: {
                ScriptPageMenu(
                    script: script, folders: folders, actions: actions,
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
                        if viewModel.showsVoicePreview, let preview = viewModel.page.voicePreview {
                            VoicePreviewStrip(
                                showing: preview.showing, isLoading: preview.isLoadingWithout,
                                onShow: viewModel.showVoice, onApprove: viewModel.approveVoice, onAdjust: viewModel.openVoiceAdjust
                            )
                            .padding(.top, 12)
                        }
                        face
                    }
                    .padding(.horizontal, Metrics.textGutter)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                // A block picked in the details: the page goes there.
                .onChange(of: viewModel.readScrollTarget) { _, target in
                    guard let target else { return }
                    viewModel.readScrollTarget = nil
                    withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo("page.section.\(target)", anchor: .top) }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.page.mode == .draft, !viewModel.page.isWriting {
                ScriptDraftBar(
                    platform: script.platform,
                    idealRange: viewModel.preset.idealRange,
                    onShape: viewModel.shape,
                    onCueBreak: viewModel.insertCueBreak,
                    onTextSize: viewModel.cycleTextSize
                )
            }
        }
        .overlay(alignment: .bottom) { selectionBar }
        .overlay { candidateOverlay }
        .sheet(isPresented: $viewModel.page.showsLengthNudge) { nudge }
        .sheet(isPresented: $viewModel.page.showsVoiceAdjust) {
            VoiceAdjustSheet { adjustments, keepsInProfile in
                Task { await viewModel.rewriteVoice(adjustments: adjustments, keepsInProfile: keepsInProfile) }
            }
        }
        .animation(.smooth(duration: 0.2), value: viewModel.selectedText != nil)
        .animation(.smooth(duration: 0.25), value: viewModel.page.candidate)
        .onAppear {
            if viewModel.page.focusesTitle {
                viewModel.page.focusesTitle = false
                focus = .title
            }
        }
        .onChange(of: viewModel.page.mode) { _, mode in
            if mode == .shaped { focus = nil }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.commitPage() }
        }
        .onChange(of: viewModel.page.title) { _, _ in viewModel.pageDidEdit() }
        .onDisappear { viewModel.leavePage() }
    }

    // MARK: - Pieces

    /// "113 WORDS · ~0:45"
    private var wordsAndTime: String {
        let zone = viewModel.zone
        return String(localized: "\(zone.words) words · ~\(DurationText.clock(zone.seconds))")
    }

    @ViewBuilder
    private var face: some View {
        @Bindable var viewModel = viewModel
        switch viewModel.page.mode {
        case .draft:
            ScriptDraftEditor(
                text: Binding(get: { viewModel.previewedText ?? viewModel.page.revealed ?? viewModel.page.text }, set: { viewModel.page.text = $0 }),
                selection: $viewModel.page.selection,
                textSize: viewModel.page.textSize,
                isLocked: viewModel.page.isWriting || viewModel.previewedText != nil,
                focus: $focus,
                onEdit: { if !viewModel.page.isWriting { viewModel.pageDidEdit() } }
            )
            .padding(.top, 10)
        case .shaped:
            ScriptShapedView(viewModel: viewModel) { Task { await viewModel.openHooks() } }
            if !viewModel.scriptTakes.isEmpty {
                ScriptTakesStrip(takes: viewModel.scriptTakes, version: script.version, onOpen: onOpenTake)
                    .padding(.top, 24)
            }
        }
    }

    @ViewBuilder
    private var selectionBar: some View {
        if viewModel.page.mode == .draft, viewModel.selectedText != nil, viewModel.page.candidate == nil {
            SelectionActionBar(isWorking: viewModel.page.isRewriting) { action in
                Task { await viewModel.rewriteSelection(action) }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 64)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var candidateOverlay: some View {
        if let candidate = viewModel.page.candidate {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture(perform: viewModel.keepMine)
                RewriteCandidateCard(candidate: candidate, onUse: viewModel.useCandidate, onKeep: viewModel.keepMine)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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
            onShape: {
                viewModel.page.showsLengthNudge = false
                viewModel.shape()
            }
        )
        .presentationDetents([.height(300)])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
    }

    private func record() {
        focus = nil
        if viewModel.recordsNow() { onRecord() }
    }
}
