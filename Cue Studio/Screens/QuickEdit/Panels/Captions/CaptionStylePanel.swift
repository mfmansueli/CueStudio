//
//  CaptionStylePanel.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Caption style, always for every line, and the one place captions are styled: the format the lines are cut by (`CaptionFormat`: one word,
/// a short phrase, two lines), the collection's presets, how lines appear (tapping one plays the current line with it), where they sit and
/// how big, and the highlight color. Captions drawn with a text's look (copied with "Apply this style to captions", or from an older
/// version) show it as Custom, first and picked, and Font changes its family, weight and color; picking a preset replaces it, on the
/// captions only. The panel expands like Text style.
struct CaptionStylePanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var frame: UIImage?

    /// The colors here are what the panel is for: larger than in other panels.
    private static let swatchDiameter: CGFloat = 34
    /// A preset card's width (`PanelPresetCard`) and the least room beside it.
    private static let presetCell: CGFloat = 104

    var body: some View {
        let tab = viewModel.captions.captionStyleTab
        PanelFrame(
            viewModel: viewModel, panel: .captionStyle,
            onReset: resetAction
        ) {
            PanelTabs(tabs: EditorPanelTab.captionStyle, selection: tab) { viewModel.panelTab = $0 }
        } content: {
            switch tab {
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

    /// Reset puts the collection's look back to its defaults (a copied look goes too).
    private var resetAction: (() -> Void)? {
        guard viewModel.edit.captionCollection != nil else { return nil }
        return { viewModel.captions.resetCaptionTheme() }
    }

    /// The collection; Clean too while it is the one in use (it is kept for edits that picked it).
    private var shownThemes: [CaptionTheme] {
        let current = viewModel.captions.captionTheme
        return current == .clean ? CaptionTheme.catalog + [.clean] : CaptionTheme.catalog
    }

    // MARK: - Tabs

    /// Every preset at once, in a grid that fills the panel (rows of three on an iPhone), with room
    /// between the names however large the text.
    @ViewBuilder
    private var presets: some View {
        // How the lines are cut into what shows at once: above the looks, as it decides how much each one holds.
        if viewModel.edit.captionCollection != nil {
            PanelSegmented(
                label: String(localized: "Format"),
                detail: viewModel.captions.captionFormat == nil ? String(localized: "as they were made") : nil,
                options: CaptionFormat.allCases.map { PanelOption($0, $0.label) },
                selection: viewModel.captions.captionFormat, height: 38, identifier: "edit.captionFormat"
            ) { viewModel.captions.setCaptionFormat($0) }
        }
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: Self.presetCell), spacing: 8, alignment: .top)],
            spacing: 12
        ) {
            // "My style" first, as in Text style: saved once, worn by the next videos' captions.
            if viewModel.edit.captionCollection != nil {
                PanelSaveStyleCard(identifier: "edit.captionStyle.saveMine", action: viewModel.captions.saveMyCaptionStyle)
            }
            if let mine = viewModel.captions.myCaptionStyle {
                PanelPresetCard(
                    name: String(localized: "My style"), sample: CaptionThemePreview.image(mine.settings), frame: frame,
                    isSelected: viewModel.captions.captionsWearMyStyle, identifier: "edit.captionPreset.mine"
                ) { viewModel.captions.applyMyCaptionStyle() }
            }
            if let look = viewModel.captions.captionCustomLook { customCard(look) }
            ForEach(shownThemes) { theme in
                PanelPresetCard(
                    name: theme.label, sample: CaptionThemePreview.image(theme), frame: frame,
                    isSelected: viewModel.captions.captionTheme == theme, identifier: "edit.captionPreset.\(theme.rawValue)"
                ) { viewModel.captions.pickCaptionTheme(theme) }
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.captionCatalog")
        if viewModel.captions.captionCustomLook != nil {
            PanelNote(text: String(localized: "Custom style copied from a text. Pick a preset to replace it."))
                .accessibilityIdentifier("edit.captionCustomNote")
        }
    }

    /// The look the captions have now when it isn't a preset: picked, drawn as the export draws it.
    private func customCard(_ look: TextLook) -> some View {
        let sample: UIImage? = if let settings = viewModel.edit.captionCollection {
            CaptionThemePreview.image(settings)
        } else {
            TypeLookPreview.image(look, use: .caption, sample: "Big idea")
        }
        return PanelPresetCard(
            name: viewModel.captions.captionCustomLookName, sample: sample, frame: frame, isSelected: true,
            identifier: "edit.captionPreset.custom"
        ) {}
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
            selection: viewModel.captions.captionReveal, identifier: "edit.captionReveal"
        ) { viewModel.captions.pickCaptionReveal($0) }
        PanelNote(text: String(localized: "Tap a style to preview it on the current line."))
        if viewModel.captions.captionReveal.followsWords, viewModel.captions.linesWithoutWordTiming > 0 {
            PanelNote(
                text: String(localized: "\(viewModel.captions.linesWithoutWordTiming) lines follow the voice approximately.")
            )
        }
    }

    @ViewBuilder
    private var position: some View {
        PanelSegmented(
            label: String(localized: "Position"),
            options: CaptionPosition.allCases.map { PanelOption($0, $0.label) },
            selection: viewModel.captions.captionPositionStop, height: 38, identifier: "edit.captionPosition"
        ) { viewModel.captions.setCaptionPositionStop($0) }
        // S · M · L · XL: four words, so a segmented control, like Position above it.
        PanelSegmented(
            label: String(localized: "Size"),
            options: CaptionSize.allCases.map { PanelOption($0, $0.label, key: "\($0.rawValue)") },
            selection: CaptionSize.nearest(to: viewModel.captions.captionPointSize), height: 38, identifier: "edit.captionSize"
        ) { viewModel.captions.setCaptionPointSize($0.points) }
        PanelNote(text: String(localized: "You can also drag the caption in the video."))
    }

    /// A preset's family (its own, or one of the video's over it) and highlight color; for a custom look, its family,
    /// weight and color.
    @ViewBuilder
    private var font: some View {
        if viewModel.captions.captionEditableLook == nil, viewModel.edit.captionCollection != nil {
            // Over a preset only the family changes: the rest stays the preset's.
            PanelChips(
                options: [PanelOption(nil, String(localized: "Preset"), key: "preset")]
                    + TextOverlayFont.editorFonts.map { PanelOption(Optional($0), $0.label, key: $0.rawValue) },
                selection: viewModel.captions.captionFace,
                font: { face, size in face.map { CueStudioFont.chip($0, size: size) } ?? .system(size: size, weight: .semibold) },
                identifier: "edit.captionFace", onSelect: viewModel.captions.setCaptionFace
            )
        }
        if let look = viewModel.captions.captionEditableLook {
            PanelChips(
                options: TextOverlayFont.editorFonts.map { PanelOption($0, $0.label) }, selection: look.font,
                font: { CueStudioFont.chip($0, size: $1) }, identifier: "edit.captionFont",
                onSelect: { family in
                    viewModel.captions.updateCaptionLook { look in
                        look.font = family
                        if !family.weights.contains(look.weight) { look.weight = family.weights[0] }
                    }
                }
            )
            PanelSegmented(
                label: String(localized: "Weight"), options: look.font.weights.map { PanelOption($0, $0.label) },
                selection: look.weight, height: 38, identifier: "edit.captionWeight"
            ) { weight in viewModel.captions.updateCaptionLook { $0.weight = weight } }
            PanelSwatches(
                label: String(localized: "Color"), colors: OverlayColor.palette, selection: look.color,
                diameter: Self.swatchDiameter, identifier: "edit.captionColor"
            ) { color in viewModel.captions.updateCaptionLook { $0.color = color } }
        }
        if let accent = viewModel.captions.captionAccent {
            accents(accent)
        }
    }

    /// The collection's highlight: the color the word being said takes, from the palette.
    private func accents(_ current: CaptionAccent) -> some View {
        PanelSwatches(
            label: String(localized: "Highlight color"), colors: OverlayColor.palette, selection: current,
            diameter: Self.swatchDiameter, identifier: "edit.captionAccent"
        ) { viewModel.captions.setCaptionAccent($0) }
    }
}
