//
//  CoverStudioView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Cover Studio, over the editor: the cover on its canvas at the top, the open step's controls under it (they scroll; the canvas
/// stays in view), the five steps at the bottom. The bar has Cancel, undo and redo, the crop guide and Done. Cancel with changes
/// asks before throwing them away.
struct CoverStudioView: View {
    @Bindable var viewModel: CoverStudioViewModel
    /// The recording's frame rate, for stepping frame by frame.
    let frameRate: Double
    let onDone: (CoverStudioViewModel) -> Void
    let onCancel: (CoverStudioViewModel) -> Void

    @State private var confirmsDiscard = false
    @State private var confirmsRemove = false
    /// While the keyboard is up the steps hide, so the cover keeps as much room as it can.
    @State private var isKeyboardUp = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let panel = panelHeight(for: proxy.size.height)
                let bar: CGFloat = isKeyboardUp ? 0 : 50
                VStack(spacing: 0) {
                    canvasArea(height: proxy.size.height - panel - bar)
                    stepPanel.frame(height: panel)
                    if !isKeyboardUp { CoverStepBar(viewModel: viewModel) }
                }
            }
            .background(Palette.bg.ignoresSafeArea())
            .toolbar { toolbar }
            .navigationTitle(Text("Cover"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task { await viewModel.start() }
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillShowNotification) { isKeyboardUp = true }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillHideNotification) { isKeyboardUp = false }
        }
        .overlay(alignment: .top) { notice }
        .confirmationDialog(Text("Discard this cover's changes?"), isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { onCancel(viewModel) }
            Button("Keep editing", role: .cancel) {}
        }
        .confirmationDialog(Text("Remove the cover?"), isPresented: $confirmsRemove, titleVisibility: .visible) {
            Button("Remove cover", role: .destructive) {
                viewModel.removeCover()
                onDone(viewModel)
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("The video is exported without a cover image.")
        }
        .accessibilityIdentifier("cover.studio")
    }

    /// The controls get about 38% of the height (more with larger text), never so much the cover gets small.
    private func panelHeight(for height: CGFloat) -> CGFloat {
        let share: CGFloat = typeSize >= .xxLarge ? 0.46 : 0.38
        return min(max(height * share, 220), 360)
    }

    private func canvasArea(height: CGFloat) -> some View {
        GeometryReader { proxy in
            let available = CGSize(width: max(1, proxy.size.width - 32), height: max(120, proxy.size.height - 16))
            let aspect = CGFloat(viewModel.aspect)
            let width = min(available.width, available.height * aspect)
            let size = CGSize(width: width.rounded(), height: (width / aspect).rounded())
            CoverCanvas(viewModel: viewModel, size: size)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: max(140, height))
    }

    private var stepPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(viewModel.step.label)
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let next = viewModel.step.next {
                    Button {
                        Haptics.selection()
                        viewModel.step = next
                    } label: {
                        HStack(spacing: 4) {
                            Text("Next: \(next.label)")
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                        }
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Palette.fill, in: Capsule())
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cover.next")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            ScrollView {
                Group {
                    switch viewModel.step {
                    case .image: CoverPictureStep(viewModel: viewModel, frameRate: frameRate)
                    case .template: CoverTemplateStep(viewModel: viewModel)
                    case .text: CoverTitleStep(viewModel: viewModel)
                    case .elements: CoverGraphicsStep(viewModel: viewModel)
                    case .effects: CoverFinishStep(viewModel: viewModel) { confirmsRemove = true }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .id(viewModel.step)
        }
        .background(Palette.Editor.panel)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Metrics.editorPanelRadius, topTrailingRadius: Metrics.editorPanelRadius, style: .continuous))
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(role: .close) {
                if viewModel.canUndo { confirmsDiscard = true } else { onCancel(viewModel) }
            }
            .accessibilityLabel(Text("Cancel"))
            .accessibilityIdentifier("cover.cancel")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { viewModel.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!viewModel.canUndo)
                .accessibilityLabel(Text("Undo"))
                .accessibilityIdentifier("cover.undo")
            Button { viewModel.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!viewModel.canRedo)
                .accessibilityLabel(Text("Redo"))
                .accessibilityIdentifier("cover.redo")
            Menu {
                Picker(selection: $viewModel.cropGuide) {
                    ForEach(CoverCropGuide.allCases) { Text($0.label).tag($0) }
                } label: { Text("Crop guide") }
            } label: {
                Image(systemName: viewModel.cropGuide == .none ? "crop" : "crop.rotate")
            }
            .accessibilityLabel(Text("Crop guide"))
            .accessibilityValue(Text(viewModel.cropGuide.label))
            .accessibilityIdentifier("cover.cropGuide")
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button { onDone(viewModel) } label: {
                Text("Done").fontWeight(.semibold).foregroundStyle(Palette.accInk)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.acc)
            .accessibilityIdentifier("cover.done")
        }
    }

    @ViewBuilder
    private var notice: some View {
        if let notice = viewModel.notice {
            Text(notice)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Palette.Editor.toast, in: Capsule())
                .padding(.top, 60)
                .transition(.toast(reduceMotion: reduceMotion))
                .task(id: notice) {
                    try? await Task.sleep(for: .seconds(2.2))
                    viewModel.notice = nil
                }
                .accessibilityIdentifier("cover.notice")
        }
    }
}
