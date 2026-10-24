//
//  CaptionAdjustTab.swift
//  Cue Studio
//

import SwiftUI

/// Caption style › Adjust: the same controls over any style (one of Cue's, a saved one, a text's look copied onto the
/// captions). Font (family, its weights, case), color, background (with its color and how solid), outline, shadow, and the
/// words marked for emphasis (once a word is marked); letter spacing under Advanced. A control shows only where it does
/// something. "Back to <style>'s look" undoes every change at once, and a note warns when the look would be hard to read on
/// bright scenes.
struct CaptionAdjustTab: View {
    @Bindable var viewModel: QuickEditViewModel
    @State private var showsAdvanced = false

    @ScaledMetric(relativeTo: .body) private var swatchDiameter: CGFloat = 34

    private var captions: CaptionsViewModel { viewModel.captions }
    private static let styleColor = String(localized: "Style's")

    var body: some View {
        if let settings = captions.captionAdjustSettings {
            let spec = settings.spec
            let changes = settings.adjustments ?? CaptionAdjustments()
            if captions.captionContrastWarning {
                PanelNote(text: String(localized: "Hard to read on bright scenes. Add a background, a thick outline or a halo."), tint: Palette.warnText)
                    .accessibilityIdentifier("edit.captionContrastWarning")
            }
            font(settings, spec: spec, changes: changes)
            colors(spec, changes: changes)
            background(spec, changes: changes)
            edges(spec, changes: changes)
            emphasis(spec, changes: changes)
            PanelAdvancedButton(
                isOpen: showsAdvanced, detail: changes.tracking == nil ? nil : PanelAdvancedButton.changed(1),
                identifier: "edit.captionAdjust.advanced"
            ) { showsAdvanced.toggle() }
            if showsAdvanced {
                PanelSlider(
                    label: String(localized: "Letter spacing"), value: spec.tracking, range: CaptionAdjustments.trackingRange, step: 0.2,
                    defaultValue: settings.styleSpec.tracking, format: .points, identifier: "edit.captionTracking",
                    onChange: { value in captions.adjustCaptions(key: "captionTracking") { $0.tracking = value } }
                )
            }
            if captions.changedCaptionLookCount > 0 {
                PanelButton(
                    label: String(localized: "Back to \(settings.theme.label)'s look"), systemImage: "arrow.uturn.backward",
                    identifier: "edit.captionAdjust.reset", action: captions.resetCaptionLook
                )
            }
        } else {
            PanelNote(text: String(localized: "Pick a style in Styles to adjust it."))
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func font(_ settings: CaptionSettings, spec: CaptionStyleSpec, changes: CaptionAdjustments) -> some View {
        PanelChips(
            options: [PanelOption(nil, String(localized: "Style's font"), key: "preset")]
                + TextOverlayFont.editorFonts.map { PanelOption(Optional($0), $0.label, key: $0.rawValue) },
            selection: settings.face,
            font: { face, size in face.map { CueStudioFont.chip($0, size: size) } ?? .system(size: size, weight: .semibold) },
            identifier: "edit.captionFace", onSelect: captions.setCaptionFace
        )
        if spec.availableWeights.count > 1 {
            PanelSegmented(
                label: String(localized: "Weight"), options: spec.availableWeights.map { PanelOption($0, $0.label) },
                selection: spec.shownWeight, height: 38, identifier: "edit.captionWeight"
            ) { weight in captions.adjustCaptions { $0.weight = weight } }
        }
        PanelSegmented(
            label: String(localized: "Case"),
            options: CaptionLetterCase.allCases.map { PanelOption($0, $0.label, accessibilityLabel: $0.accessibilityLabel) },
            selection: spec.letterCase, height: 38, identifier: "edit.captionCase"
        ) { letterCase in captions.adjustCaptions { $0.letterCase = letterCase } }
    }

    private func colors(_ spec: CaptionStyleSpec, changes: CaptionAdjustments) -> some View {
        PanelSwatches(
            label: String(localized: "Text color"), colors: OverlayColor.palette,
            selection: changes.textColor ?? OverlayColor.matching(spec.textColor), diameter: swatchDiameter,
            reset: changes.textColor == nil ? nil : (Self.styleColor, { captions.adjustCaptions { $0.textColor = nil } }),
            identifier: "edit.captionTextColor"
        ) { color in captions.adjustCaptions { $0.textColor = color } }
    }

    @ViewBuilder
    private func background(_ spec: CaptionStyleSpec, changes: CaptionAdjustments) -> some View {
        let kind = CaptionBackground(spec.plate)
        PanelSegmented(
            label: String(localized: "Background"), options: CaptionBackground.allCases.map { PanelOption($0, $0.label) },
            selection: kind, height: 38, identifier: "edit.captionBackground"
        ) { picked in captions.adjustCaptions { $0.background = picked } }
        if kind != .none {
            PanelSwatches(
                label: String(localized: "Background color"), colors: OverlayColor.palette,
                selection: changes.backgroundColor ?? OverlayColor.matching(spec.plateColor), diameter: swatchDiameter,
                reset: changes.backgroundColor == nil ? nil : (Self.styleColor, { captions.adjustCaptions { $0.backgroundColor = nil } }),
                identifier: "edit.captionBackgroundColor"
            ) { color in captions.adjustCaptions { $0.backgroundColor = color } }
            PanelSlider(
                label: String(localized: "Background opacity"), value: ((spec.plateColor?.alpha ?? 1) * 100).rounded(), range: 30...100, step: 5,
                defaultValue: nil, format: .percent, identifier: "edit.captionBackgroundOpacity",
                onChange: { value in captions.adjustCaptions(key: "captionBackgroundOpacity") { $0.backgroundOpacity = value / 100 } }
            )
        }
    }

    @ViewBuilder
    private func edges(_ spec: CaptionStyleSpec, changes: CaptionAdjustments) -> some View {
        let outline = CaptionOutlineWeight.nearest(to: spec.outline?.width)
        PanelSegmented(
            label: String(localized: "Outline"), options: CaptionOutlineWeight.allCases.map { PanelOption($0, $0.label) },
            selection: outline, height: 38, identifier: "edit.captionOutline"
        ) { picked in captions.adjustCaptions { $0.outline = picked } }
        if outline != .none {
            PanelSwatches(
                label: String(localized: "Outline color"), colors: OverlayColor.palette,
                selection: changes.outlineColor ?? OverlayColor.matching(spec.outline?.color), diameter: swatchDiameter,
                reset: changes.outlineColor == nil ? nil : (Self.styleColor, { captions.adjustCaptions { $0.outlineColor = nil } }),
                identifier: "edit.captionOutlineColor"
            ) { color in captions.adjustCaptions { $0.outlineColor = color } }
        }
        PanelSegmented(
            label: String(localized: "Shadow"), options: CaptionShadowStyle.allCases.map { PanelOption($0, $0.label) },
            selection: CaptionShadowStyle(spec.shadow, textColor: spec.textColor), height: 38, identifier: "edit.captionShadow"
        ) { picked in captions.adjustCaptions { $0.shadow = picked } }
    }

    /// The marked words' color and size, once a word is marked; until then, where to mark them.
    @ViewBuilder
    private func emphasis(_ spec: CaptionStyleSpec, changes: CaptionAdjustments) -> some View {
        if viewModel.edit.captions.contains(where: { !$0.emphasis.isEmpty }) {
            PanelSwatches(
                label: String(localized: "Emphasis color"), colors: OverlayColor.palette, selection: spec.emphasisColor, diameter: swatchDiameter,
                reset: changes.emphasisColor == nil ? nil : (Self.styleColor, { captions.adjustCaptions { $0.emphasisColor = nil } }),
                identifier: "edit.captionEmphasisColor"
            ) { color in captions.adjustCaptions { $0.emphasisColor = color } }
            PanelSegmented(
                label: String(localized: "Emphasis size"), options: CaptionEmphasisSize.allCases.map { PanelOption($0, $0.label) },
                selection: CaptionEmphasisSize.nearest(to: spec.emphasisScale), height: 38, identifier: "edit.captionEmphasisSize"
            ) { size in captions.adjustCaptions { $0.emphasisSize = size } }
        } else {
            PanelNote(text: String(localized: "To emphasize a word, open its line in Captions › More › Emphasis."))
        }
    }
}
