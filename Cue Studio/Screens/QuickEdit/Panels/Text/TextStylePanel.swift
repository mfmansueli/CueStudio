//
//  TextStylePanel.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Text style for the picked text. Fixed on top: its words (the keyboard comes up when it was just
/// added) and the tabs, Presets · Font · Color · Motion, spread over the width. Under the look's tabs,
/// what the look changes ("This title" or "All texts · 3": the words, timing and motion are always
/// this text's), the controls, and "Apply this style to captions", which copies the look onto the
/// captions once, after asking. Motion is the picked text's alone. The panel expands (the header's
/// button, or a drag) to give the controls the room the video gives up.
struct TextStylePanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var frame: UIImage?
    @FocusState private var writes: Bool

    /// What the preset cards say.
    private static let sample = "Big idea"
    /// The colors here are what the panel is for: larger than in other panels.
    private static let swatchDiameter: CGFloat = 34

    var body: some View {
        if let text = viewModel.selectedText {
            let tab = viewModel.textStyleTab
            PanelFrame(viewModel: viewModel, panel: .textStyle) {
                fixed(text, tab: tab)
            } content: {
                if viewModel.textStyleTabChangesLook { scope }
                switch tab {
                case .font: font(text)
                case .color: color(text)
                case .motion: MotionKeyframeControls(viewModel: viewModel)
                default: presets(text)
                }
                if viewModel.textStyleTabChangesLook, viewModel.canCopyStyleToCaptions { copyToCaptions }
            }
            .task {
                guard frame == nil else { return }
                frame = await thumbnails.thumbnail(for: viewModel.videoURL, maxPixelSize: 240)
            }
            .onAppear(perform: focusIfAsked)
            .onChange(of: viewModel.focusesTextField) { _, _ in focusIfAsked() }
            .alert(
                "Apply this style to captions?",
                isPresented: Binding(
                    get: { viewModel.captionStyleCopySourceID != nil },
                    set: { if !$0 { viewModel.cancelCopyingStyleToCaptions() } }
                )
            ) {
                Button("Cancel", role: .cancel) { viewModel.cancelCopyingStyleToCaptions() }
                    .accessibilityIdentifier("edit.style.copyToCaptions.cancel")
                Button("Apply") { viewModel.copyStyleToCaptions() }
                    .accessibilityIdentifier("edit.style.copyToCaptions.apply")
            } message: {
                Text(viewModel.captionStyleCopyMessage)
            }
        }
    }

    private func focusIfAsked() {
        guard viewModel.focusesTextField else { return }
        viewModel.focusesTextField = false
        writes = true
    }

    // MARK: - Fixed rows

    /// The words and the tabs: what stays in reach over the keyboard and while the content scrolls.
    private func fixed(_ text: TextOverlay, tab: EditorPanelTab) -> some View {
        VStack(spacing: 0) {
            TextField(viewModel.textFieldPlaceholder, text: Binding(
                get: { text.text },
                set: { viewModel.setTextContent(text.id, $0) }
            ))
            .font(.system(.body))
            .focused($writes)
            .submitLabel(.done)
            .padding(.horizontal, 14)
            .frame(minHeight: Metrics.buttonHeight)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .accessibilityIdentifier("edit.textField")
            PanelTabs(tabs: EditorPanelTab.textStyle, selection: tab) { viewModel.panelTab = $0 }
        }
    }

    /// What the look changes: this text or every text. A note says what never follows the scope.
    private var scope: some View {
        VStack(alignment: .leading, spacing: 6) {
            PanelSegmented(
                label: String(localized: "Style applies to"),
                options: QuickEditViewModel.textStyleScopes.map { PanelOption($0, viewModel.textStyleScopeLabel($0)) },
                selection: viewModel.textStyleScope, height: 38, identifier: "edit.style.scope"
            ) { viewModel.textStyleScope = $0 }
            if viewModel.textStyleScope == .allTexts {
                PanelNote(text: String(localized: "Words, timing and motion stay with each text."))
                    .accessibilityIdentifier("edit.style.scopeNote")
            }
        }
    }

    /// Copies the look onto the captions once; asks first (`TextStylePanel.body`'s alert).
    private var copyToCaptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(Palette.Editor.separator).frame(height: 0.5)
            PanelButton(
                label: String(localized: "Apply this style to captions"), systemImage: "captions.bubble",
                identifier: "edit.style.copyToCaptions", action: viewModel.askToCopyStyleToCaptions
            )
        }
        .padding(.top, 4)
    }

    // MARK: - Tabs

    /// The styles in a row, then Size and Glow and the colors: the whole look in one place.
    @ViewBuilder
    private func presets(_ text: TextOverlay) -> some View {
        styleCards
        PanelSlider(
            label: String(localized: "Size"), value: viewModel.pickedTextPointSize, range: CueSliderSpec.textPoints.range,
            step: CueSliderSpec.textPoints.step ?? 2, defaultValue: CueSliderSpec.textPoints.defaultValue, format: .points, identifier: "edit.textSize"
        ) { viewModel.restyleText(.size($0), key: "textSize") }
        PanelSlider(
            label: String(localized: "Glow"), value: text.glow * 100, range: CueSliderSpec.textGlow.range,
            step: CueSliderSpec.textGlow.step ?? 5, defaultValue: CueSliderSpec.textGlow.defaultValue, format: .percent,
            identifier: "edit.textGlow"
        ) { viewModel.restyleText(.glow($0 / 100), key: "textGlow") }
        PanelSwatches(
            label: String(localized: "Text"), colors: OverlayColor.textSwatches, selection: text.color,
            diameter: Self.swatchDiameter, identifier: "edit.textColor"
        ) { viewModel.restyleText(.color($0)) }
    }

    private var styleCards: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 8) {
                PanelSaveStyleCard(action: viewModel.saveMyStyle)
                if let mine = viewModel.myStyle {
                    PanelPresetCard(
                        name: String(localized: "My style"), sample: TypeLookPreview.image(mine, use: .title, sample: Self.sample),
                        frame: frame, isSelected: viewModel.pickedTextIsMyStyle, identifier: "edit.style.mine"
                    ) { viewModel.pickTextPreset(nil) }
                }
                ForEach(TypePreset.editorPresets) { preset in
                    PanelPresetCard(
                        name: preset.label, sample: TypeLookPreview.image(preset.look(for: .title), use: .title, sample: Self.sample),
                        frame: frame, isSelected: viewModel.pickedTextPreset == preset, identifier: "edit.style.\(preset.rawValue)"
                    ) { viewModel.pickTextPreset(preset) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    @ViewBuilder
    private func font(_ text: TextOverlay) -> some View {
        PanelChips(
            options: TextOverlayFont.editorFonts.map { PanelOption($0, $0.label) }, selection: text.font,
            font: { CueStudioFont.chip($0) }, identifier: "edit.textFont",
            onSelect: { viewModel.restyleText(.font($0)) }
        )
        PanelSegmented(
            label: String(localized: "Weight"), options: text.font.weights.map { PanelOption($0, $0.label) },
            selection: text.weight, height: 38, identifier: "edit.textWeight"
        ) { viewModel.restyleText(.weight($0)) }
    }

    @ViewBuilder
    private func color(_ text: TextOverlay) -> some View {
        PanelSwatches(
            label: String(localized: "Text"), colors: OverlayColor.textSwatches, selection: text.color,
            diameter: Self.swatchDiameter, identifier: "edit.textColor"
        ) { viewModel.restyleText(.color($0)) }
        PanelSegmented(
            label: String(localized: "Background"), options: TextOverlayBackground.allCases.map { PanelOption($0, $0.label) },
            selection: text.background, height: 38, identifier: "edit.textBackground"
        ) { viewModel.restyleText(.background($0)) }
        if text.background != .none {
            PanelSwatches(
                label: String(localized: "Background color"), colors: OverlayColor.backgroundSwatches,
                selection: text.backgroundColor, diameter: Self.swatchDiameter, identifier: "edit.textBackgroundColor"
            ) { viewModel.restyleText(.backgroundColor($0)) }
        }
        PanelSegmented(
            label: String(localized: "Shadow"), options: TextShadowStyle.allCases.map { PanelOption($0, $0.label) },
            selection: TextShadowStyle(hasShadow: text.hasShadow, hasOutline: text.hasOutline), height: 38, identifier: "edit.textShadow"
        ) { viewModel.restyleText(.shadow($0)) }
    }
}
