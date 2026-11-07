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
    /// Naming a cover style (Template's Save style card, or a saved style's Rename there).
    @State private var naming: StyleNameRequest?
    /// While the keyboard is up the steps and the panel's header hide and the controls take the room the cover can spare, so the
    /// field and the control that comes after typing (the title's highlighted words, a tag's color) stay in view.
    @State private var isKeyboardUp = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let panel = isKeyboardUp ? typingPanelHeight(for: proxy.size.height) : panelHeight(for: proxy.size.height)
                let bar: CGFloat = isKeyboardUp ? 0 : 50
                VStack(spacing: 0) {
                    // Its messages as the editor's toasts, over the top of the cover.
                    canvasArea(height: proxy.size.height - panel - bar)
                        .modifier(EditorToastHost())
                        .environment(viewModel.toast)
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
        // A script's face that arrived draws the title again in it.
        .onChange(of: viewModel.fontPacks?.generation) { viewModel.scheduleRender() }
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillShowNotification) { isKeyboardUp = true }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillHideNotification) { isKeyboardUp = false }
        }
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

    /// While typing the cover keeps under a third of what's above the keyboard, at most 150 pt (still showing the words typed):
    /// on an iPhone SE that leaves the title field, its suggestions, Words and the highlighted words above the keyboard.
    private func typingPanelHeight(for height: CGFloat) -> CGFloat {
        max(160, height - min(150, height * 0.28))
    }

    private func canvasArea(height: CGFloat) -> some View {
        GeometryReader { proxy in
            let available = CGSize(width: max(1, proxy.size.width - 32), height: max(74, proxy.size.height - 16))
            let aspect = CGFloat(viewModel.aspect)
            let width = min(available.width, available.height * aspect)
            let size = CGSize(width: width.rounded(), height: (width / aspect).rounded())
            CoverCanvas(viewModel: viewModel, size: size)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // The floor only binds while typing on a small iPhone (the panel never takes more than 360 pt otherwise).
        .frame(height: max(90, height))
    }

    private var stepPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isKeyboardUp { stepHeader }
            ScrollView {
                Group {
                    switch viewModel.step {
                    case .image: CoverPictureStep(viewModel: viewModel, frameRate: frameRate)
                    case .template: CoverTemplateStep(viewModel: viewModel, naming: $naming)
                    case .text: CoverTitleStep(viewModel: viewModel)
                    case .elements: CoverGraphicsStep(viewModel: viewModel)
                    case .effects: CoverEffectsStep(viewModel: viewModel) { confirmsRemove = true }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .styleNamePrompt($naming) { purpose, name in
                switch purpose {
                case .save: viewModel.saveCoverStyle(named: name)
                case .rename(let id): viewModel.renameCoverStyle(id, to: name)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .id(viewModel.step)
        }
        .background(Palette.Editor.panel)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Metrics.editorPanelRadius, topTrailingRadius: Metrics.editorPanelRadius, style: .continuous))
    }

    /// The open step's name and "Next: <step>".
    private var stepHeader: some View {
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
                        // With the largest text sizes, just "Next": the step's name would be cut.
                        if typeSize.isAccessibilitySize { Text("Next") } else { Text(String(inInterfaceLanguage: LocalizedStringResource(
                            "coverStudio.next", defaultValue: "Next: \(next.label)",
                            comment: "Cover studio: the button that goes on to the next step, naming it. An action, not a status."
                        ))) }
                        Image(systemName: "chevron.right").font(.editorGlyph(EditorGlyph.chip, weight: .bold))
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
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // "Cover" when the bar has room for the whole word; on a small screen (iPhone SE) the buttons
        // leave none, and a cut "C…" says nothing: the step's name under the cover says where you are.
        ToolbarItem(placement: .principal) {
            ViewThatFits(in: .horizontal) {
                Text("Cover")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
            }
        }
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
}
