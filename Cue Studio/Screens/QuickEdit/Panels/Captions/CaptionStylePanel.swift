//
//  CaptionStylePanel.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Caption style, always for every line: the collection's presets, how lines appear (tapping one
/// plays the current line with it), where they sit and how big, and the highlight color (or, for
/// captions drawn with a text look, its family, weight and color).
struct CaptionStylePanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var frame: UIImage?

    var body: some View {
        PanelFrame(
            viewModel: viewModel, panel: .captionStyle,
            onReset: resetAction
        ) {
            PanelTabs(tabs: EditorPanelTab.captionStyle, selection: viewModel.panelTab) { viewModel.panelTab = $0 }
        } content: {
            switch viewModel.panelTab {
            case .reveal: reveal
            case .position: position
            case .font: font
            default: presets
            }
        }
        .task {
            guard frame == nil else { return }
            frame = await thumbnails.thumbnail(for: viewModel.videoURL, maxPixelSize: 240)
        }
    }

    /// Reset puts the collection's look back to its defaults.
    private var resetAction: (() -> Void)? {
        guard viewModel.edit.captionCollection != nil else { return nil }
        return { viewModel.resetCaptionTheme() }
    }

    // MARK: - Tabs

    private var presets: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(CaptionTheme.allCases) { theme in
                    PanelPresetCard(
                        name: theme.label, sample: CaptionThemePreview.image(theme), frame: frame,
                        isSelected: viewModel.captionTheme == theme, identifier: "edit.captionPreset.\(theme.rawValue)"
                    ) { viewModel.pickCaptionTheme(theme) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
        .accessibilityIdentifier("edit.captionCatalog")
    }

    @ViewBuilder
    private var reveal: some View {
        PanelTiles(
            options: [
                PanelOption(CaptionAnimation.line, CaptionAnimation.line.label, systemImage: "text.alignleft"),
                PanelOption(CaptionAnimation.fade, CaptionAnimation.fade.label, systemImage: "circle.lefthalf.filled"),
                PanelOption(CaptionAnimation.groups, CaptionAnimation.groups.label, systemImage: "text.word.spacing"),
                PanelOption(CaptionAnimation.highlight, CaptionAnimation.highlight.label, systemImage: "highlighter"),
                PanelOption(CaptionAnimation.box, CaptionAnimation.box.label, systemImage: "character.textbox"),
            ],
            selection: viewModel.captionReveal, identifier: "edit.captionReveal"
        ) { viewModel.pickCaptionReveal($0) }
        PanelNote(text: String(localized: "Tap a style to preview it on the current line."))
        if viewModel.captionReveal.followsWords, viewModel.linesWithoutWordTiming > 0 {
            PanelNote(
                text: String(localized: "\(viewModel.linesWithoutWordTiming) lines show whole: their words don't have their own times."),
                tint: Palette.warnText
            )
        }
    }

    @ViewBuilder
    private var position: some View {
        PanelSegmented(
            label: String(localized: "Position"),
            options: CaptionPosition.allCases.map { PanelOption($0, $0.label) },
            selection: viewModel.captionPositionStop, identifier: "edit.captionPosition"
        ) { viewModel.setCaptionPositionStop($0) }
        PanelSlider(
            label: String(localized: "Size"), value: viewModel.captionPointSize, range: QuickEditViewModel.captionSizeRange,
            format: .points, identifier: "edit.captionSize"
        ) { viewModel.setCaptionPointSize($0) }
        PanelNote(text: String(localized: "You can also drag the caption in the video."))
    }

    @ViewBuilder
    private var font: some View {
        if let accent = viewModel.captionAccent {
            accents(accent)
        } else {
            let look = viewModel.edit.captionLook ?? TypePreset.cue.look(for: .caption)
            PanelChips(
                options: TextOverlayFont.editorFonts.map { PanelOption($0, $0.label) }, selection: look.font,
                font: { CueStudioFont.chip($0) }, identifier: "edit.captionFont",
                onSelect: { family in
                    viewModel.updateCaptionLook { look in
                        look.font = family
                        if !family.weights.contains(look.weight) { look.weight = family.weights[0] }
                    }
                }
            )
            PanelSegmented(
                label: String(localized: "Weight"), options: look.font.weights.map { PanelOption($0, $0.label) },
                selection: look.weight, identifier: "edit.captionWeight"
            ) { weight in viewModel.updateCaptionLook { $0.weight = weight } }
            PanelSwatches(
                label: String(localized: "Color"), colors: OverlayColor.textSwatches, selection: look.color, identifier: "edit.captionColor"
            ) { color in viewModel.updateCaptionLook { $0.color = color } }
        }
    }

    /// The collection's highlight: the color the word being said takes.
    private func accents(_ current: CaptionAccent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Highlight color").font(.system(.subheadline, weight: .semibold))
            HStack(spacing: 4) {
                ForEach(CaptionAccent.allCases) { accent in
                    let parts = accent.components
                    let isOn = accent == current
                    Button {
                        Haptics.selection()
                        viewModel.setCaptionAccent(accent)
                    } label: {
                        Circle()
                            .fill(Color(red: parts.red, green: parts.green, blue: parts.blue))
                            .frame(width: 30, height: 30)
                            .padding(3)
                            .overlay(Circle().strokeBorder(isOn ? Palette.acc : .clear, lineWidth: 2))
                            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(accent.label))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("edit.captionAccent.\(accent.rawValue)")
                }
            }
        }
    }
}
