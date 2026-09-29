//
//  QuickEditView.swift
//  Cue Studio
//

import SwiftUI

/// Quick edit: Cancel / "Quick edit · Original 1:04" (or "1:04 → 0:58") / Done, the live preview
/// (tap to play or pause), the current tool, the tools of the current category in a row, and the
/// categories along the bottom: Edit (Trim, Clean Up, Remove Pauses, Speed), Add (Text, Media,
/// Voice-over), Polish (Style, Audio, Adjust, Filters, Crop, Transitions), Captions and Cover.
/// Tools with a timeline carry their own play button, time, undo and redo, and make the preview
/// smaller to give it room.
struct QuickEditView: View {
    @State private var viewModel: QuickEditViewModel
    let onClose: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    init(take: Take, services: AppServices, onClose: @escaping () -> Void) {
        let languages = services.languages
        _viewModel = State(initialValue: QuickEditViewModel(
            take: take, takes: services.takes, library: services.library,
            editing: services.editing, drafts: services.drafts, toast: services.toast,
            speechLanguage: { languages.speechRequest(for: $0) }
        ))
        self.onClose = onClose
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, Metrics.gutter)
            GeometryReader { proxy in
                QuickEditPreview(viewModel: viewModel, size: previewSize(in: proxy.size))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 12)
            toolPanel
                .frame(height: panelHeight, alignment: .top)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 14)
                .disabled(!viewModel.isReady)
                .opacity(viewModel.isReady ? 1 : 0.4)
            toolRow
                .padding(.top, 6)
            toolbar
                .padding(.horizontal, 10)
        }
        .background(Palette.bg.ignoresSafeArea())
        .toastHost()
        .task { await viewModel.prepare() }
        .onChange(of: viewModel.tool) { _, tool in
            // Not tied to the tool: leaving Clean Up doesn't stop it listening.
            if tool == .cleanUp || tool == .removePauses { Task { await viewModel.analyzeIfNeeded() } }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.editingTextID != nil },
            set: { if !$0 { viewModel.editingTextID = nil } }
        )) {
            if let id = viewModel.editingTextID {
                TextOverlaySheet(viewModel: viewModel, textID: id)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.editingCaptionID != nil },
            set: { if !$0 { viewModel.endEditingCaption() } }
        )) {
            if let id = viewModel.editingCaptionID {
                CaptionLineSheet(viewModel: viewModel, lineID: id)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.pauseAndKeepDraft() }
        }
        .onDisappear { viewModel.pauseAndKeepDraft() }
        .animation(.smooth(duration: 0.3), value: viewModel.tool)
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            Button("Cancel") {
                viewModel.cancel()
                onClose()
            }
            .buttonStyle(.cueGlass(.compact, expands: false))
            .accessibilityIdentifier("edit.cancelButton")
            Spacer()
            VStack(spacing: 1) {
                Text("Quick edit").font(.body.weight(.semibold))
                Text(viewModel.durationChange)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("edit.durationChange")
            }
            Spacer()
            Button("Done") {
                viewModel.done()
                onClose()
            }
            .buttonStyle(.cuePrimary(.compact, expands: false))
            .accessibilityIdentifier("edit.doneButton")
        }
        .frame(height: Metrics.hitTarget)
    }

    @ViewBuilder
    private var toolPanel: some View {
        switch viewModel.tool {
        case .trim: TrimToolView(viewModel: viewModel)
        case .cleanUp: CleanUpToolView(viewModel: viewModel)
        case .audio: AudioToolView(viewModel: viewModel)
        case .adjust: AdjustToolView(viewModel: viewModel)
        case .filters: FiltersToolView(viewModel: viewModel)
        case .crop: CropToolView(viewModel: viewModel)
        case .captions: CaptionsToolView(viewModel: viewModel)
        case .removePauses: RemovePausesToolView(viewModel: viewModel)
        case .speed: SpeedToolView(viewModel: viewModel)
        case .text: TextToolView(viewModel: viewModel)
        case .media: MediaToolView(viewModel: viewModel)
        case .voiceOver: VoiceOverToolView(viewModel: viewModel)
        case .style: StyleToolView(viewModel: viewModel)
        case .transitions: TransitionsToolView(viewModel: viewModel)
        case .cover: CoverToolView(viewModel: viewModel)
        }
    }

    /// The tools of the current category, when it has more than one.
    @ViewBuilder
    private var toolRow: some View {
        let tools = viewModel.tool.category.tools
        if tools.count > 1 {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(tools) { tool in
                        let isOn = viewModel.tool == tool
                        Button { viewModel.tool = tool } label: {
                            FilterChip(label: tool.label, isSelected: isOn, systemImage: tool.systemImage, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                        .accessibilityIdentifier("edit.tool.\(tool.rawValue)")
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }
            .scrollIndicators(.hidden)
            .frame(height: Metrics.hitTarget)
            .disabled(!viewModel.isReady || viewModel.isRecordingVoiceOver)
        }
    }

    /// The categories along the bottom. Each opens on the tool used last in it.
    private var toolbar: some View {
        HStack(spacing: 0) {
            ForEach(QuickEditCategory.allCases) { category in
                let isOn = viewModel.tool.category == category
                Button {
                    viewModel.tool = viewModel.lastTool[category] ?? category.tools[0]
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: category.systemImage).font(.system(size: 19, weight: .medium))
                        Text(category.label)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isOn ? Palette.acc : Palette.ink2)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("edit.category.\(category.rawValue)")
            }
        }
        .padding(.horizontal, 6)
        .background(Palette.toolbarFill, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .disabled(!viewModel.isReady || viewModel.isRecordingVoiceOver)
    }

    /// Tools with a timeline or a list need room; the others are shorter.
    private var panelHeight: CGFloat {
        switch viewModel.tool {
        case .trim: 262
        case .cleanUp: 322
        case .text, .media, .voiceOver: 228
        case .removePauses: 236
        case .speed: 200
        case .transitions: 230
        case .style: 214
        case .cover: 196
        case .captions: 300
        case .audio, .adjust, .filters, .crop: 190
        }
    }

    /// The take's frame, as large as fits (up to 370 × 464 pt on the design's screen).
    private func previewSize(in available: CGSize) -> CGSize {
        let aspect = viewModel.edit.aspect.widthOverHeight
        let maxWidth = min(available.width - 32, 370)
        let maxHeight = available.height
        var width = maxHeight * aspect
        var height = maxHeight
        if width > maxWidth {
            width = maxWidth
            height = maxWidth / aspect
        }
        return CGSize(width: width.rounded(), height: height.rounded())
    }
}
