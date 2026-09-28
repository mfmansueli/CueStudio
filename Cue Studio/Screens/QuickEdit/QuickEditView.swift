//
//  QuickEditView.swift
//  Cue Studio
//

import SwiftUI

/// Quick edit: Cancel / "Quick edit · Original 1:04" (or "1:04 → 0:58") / Done, the live preview
/// (tap to play or pause), the current tool and the seven tools along the bottom. Trim and Clean Up
/// carry their own play button, time, undo and redo, and make the preview smaller to give the
/// timeline room.
struct QuickEditView: View {
    @State private var viewModel: QuickEditViewModel
    let onClose: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    init(take: Take, services: AppServices, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: QuickEditViewModel(
            take: take, takes: services.takes, library: services.library,
            editing: services.editing, drafts: services.drafts, toast: services.toast
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
            toolbar
                .padding(.horizontal, 10)
        }
        .background(Palette.bg.ignoresSafeArea())
        .toastHost()
        .task { await viewModel.prepare() }
        .onChange(of: viewModel.tool) { _, tool in
            // Not tied to the tool: leaving Clean Up doesn't stop it listening.
            if tool == .cleanUp { Task { await viewModel.analyzeIfNeeded() } }
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
        }
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            ForEach(QuickEditTool.allCases) { tool in
                let isOn = viewModel.tool == tool
                Button { viewModel.tool = tool } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.systemImage).font(.system(size: 19, weight: .medium))
                        Text(tool.label)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isOn ? Palette.acc : Palette.ink2)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("edit.tool.\(tool.rawValue)")
            }
        }
        .padding(.horizontal, 6)
        .background(Palette.toolbarFill, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .disabled(!viewModel.isReady)
    }

    /// Trim and Clean Up need room for their timeline and list; the other tools are shorter.
    private var panelHeight: CGFloat {
        switch viewModel.tool {
        case .trim: 262
        case .cleanUp: 322
        case .audio, .adjust, .filters, .crop, .captions: 190
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
