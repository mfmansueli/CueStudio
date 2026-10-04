//
//  TextStylePanel.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Text style for the picked text: its words on top (the keyboard comes up when it was just
/// added), what changes ("This title", "All texts · 3", "+ Captions"), then Presets, Font, Color
/// and Motion. On a compact screen the tabs sit on the scope's row.
struct TextStylePanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(\.editorHeightClass) private var heightClass
    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var frame: UIImage?
    @FocusState private var writes: Bool

    /// What the preset cards say.
    private static let sample = "Big idea"

    var body: some View {
        if let text = viewModel.selectedText {
            PanelFrame(viewModel: viewModel, panel: .textStyle) {
                fixed(text)
            } content: {
                switch viewModel.panelTab {
                case .font: font(text)
                case .color: color(text)
                case .motion: MotionKeyframeControls(viewModel: viewModel)
                default: presets(text)
                }
            }
            .task {
                guard frame == nil else { return }
                frame = await thumbnails.thumbnail(for: viewModel.videoURL, maxPixelSize: 240)
            }
            .onAppear(perform: focusIfAsked)
            .onChange(of: viewModel.focusesTextField) { _, _ in focusIfAsked() }
        }
    }

    private func focusIfAsked() {
        guard viewModel.focusesTextField else { return }
        viewModel.focusesTextField = false
        writes = true
    }

    // MARK: - Fixed rows

    private func fixed(_ text: TextOverlay) -> some View {
        VStack(spacing: 0) {
            TextField(viewModel.textFieldPlaceholder, text: Binding(
                get: { text.text },
                set: { viewModel.setTextContent(text.id, $0) }
            ))
            .font(.system(.callout))
            .focused($writes)
            .submitLabel(.done)
            .padding(.horizontal, 14)
            .frame(height: Metrics.hitTarget)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .accessibilityIdentifier("edit.textField")
            if heightClass == .regular {
                scope.padding(.horizontal, 16).padding(.bottom, 8)
                PanelTabs(tabs: EditorPanelTab.textStyle, selection: viewModel.panelTab) { viewModel.panelTab = $0 }
            } else {
                // Compact: the tabs on the scope's row, sideways.
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        scope.frame(width: 260)
                        PanelTabs(tabs: EditorPanelTab.textStyle, selection: viewModel.panelTab, isInline: true) { viewModel.panelTab = $0 }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .padding(.bottom, 4)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.editorSeparator).frame(height: 0.5) }
            }
        }
    }

    private var scope: some View {
        PanelSegmented(
            options: QuickEditViewModel.textStyleScopes.map { PanelOption($0, viewModel.textStyleScopeLabel($0)) },
            selection: viewModel.textStyleScope, height: 30, identifier: "edit.style.scope"
        ) { viewModel.textStyleScope = $0 }
    }

    // MARK: - Tabs

    /// The styles in a row, then Size and Glow as orbs and the colors: the whole look in one place.
    @ViewBuilder
    private func presets(_ text: TextOverlay) -> some View {
        styleCards
        PanelSlider(
            label: String(localized: "Size"), value: viewModel.pickedTextPointSize, range: TextStyleEdit.sizeRange,
            format: .points, identifier: "edit.textSize"
        ) { viewModel.restyleText(.size($0), key: "textSize") }
        PanelSlider(
            label: String(localized: "Glow"), value: text.glow * 100, range: 0...100, step: 5, format: .percent,
            identifier: "edit.textGlow"
        ) { viewModel.restyleText(.glow($0 / 100), key: "textGlow") }
        PanelSwatches(
            label: String(localized: "Text"), colors: OverlayColor.textSwatches, selection: text.color, identifier: "edit.textColor"
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
            selection: text.weight, identifier: "edit.textWeight"
        ) { viewModel.restyleText(.weight($0)) }
    }

    @ViewBuilder
    private func color(_ text: TextOverlay) -> some View {
        PanelSwatches(
            label: String(localized: "Text"), colors: OverlayColor.textSwatches, selection: text.color, identifier: "edit.textColor"
        ) { viewModel.restyleText(.color($0)) }
        PanelSegmented(
            label: String(localized: "Background"), options: TextOverlayBackground.allCases.map { PanelOption($0, $0.label) },
            selection: text.background, identifier: "edit.textBackground"
        ) { viewModel.restyleText(.background($0)) }
        if text.background != .none {
            PanelSwatches(
                label: String(localized: "Background color"), colors: OverlayColor.backgroundSwatches,
                selection: text.backgroundColor, identifier: "edit.textBackgroundColor"
            ) { viewModel.restyleText(.backgroundColor($0)) }
        }
        PanelSegmented(
            label: String(localized: "Shadow"), options: TextShadowStyle.allCases.map { PanelOption($0, $0.label) },
            selection: TextShadowStyle(hasShadow: text.hasShadow, hasOutline: text.hasOutline), identifier: "edit.textShadow"
        ) { viewModel.restyleText(.shadow($0)) }
    }
}
