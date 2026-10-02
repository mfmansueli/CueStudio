//
//  BackgroundPanel.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Background (the recording under the playhead, or the picked clip alone when opened from it; the
/// file never changes): Original, Blur, Color or Image behind the person Vision finds on the
/// iPhone. Advanced: the blur's strength, and Color key for a green or blue screen with Tolerance,
/// Edge and Spill. For a clip, Reset gives it its recording's background again.
struct BackgroundPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let effect = viewModel.currentBackground
        PanelFrame(viewModel: viewModel, panel: .background, onReset: reset) {
            PanelTiles(
                options: [
                    PanelOption(BackgroundStyle.original, BackgroundStyle.original.label, systemImage: "person"),
                    PanelOption(BackgroundStyle.blur, BackgroundStyle.blur.label, systemImage: "drop"),
                    PanelOption(BackgroundStyle.color, BackgroundStyle.color.label, systemImage: "paintpalette"),
                    PanelOption(BackgroundStyle.image, BackgroundStyle.image.label, systemImage: "photo"),
                ],
                selection: effect.style, identifier: "edit.background"
            ) { style in
                viewModel.setBackgroundStyle(style)
                if style == .image, effect.imageFileName == nil { viewModel.requestPhoto(.background) }
            }
            if effect.cutout == .person, effect.style != .original, viewModel.canFindPeople == false {
                PanelNote(
                    text: String(localized: "This iPhone can’t find people in video. Use a color key with a green or blue screen."),
                    tint: Palette.warnText
                )
                .accessibilityIdentifier("edit.backgroundUnavailable")
            }
            switch effect.style {
            case .color:
                PanelSwatches(
                    label: String(localized: "Color"), colors: OverlayColor.backdropSwatches, selection: effect.color,
                    identifier: "edit.backgroundColor"
                ) { color in viewModel.updateBackground { $0.color = color } }
            case .image:
                PanelButton(
                    label: viewModel.isImportingBackground
                        ? String(localized: "Adding…")
                        : (effect.imageFileName == nil ? String(localized: "Choose a photo") : String(localized: "Change photo")),
                    systemImage: "photo", isEnabled: !viewModel.isImportingBackground, identifier: "edit.backgroundPhotoButton"
                ) { viewModel.requestPhoto(.background) }
            default:
                EmptyView()
            }
            PanelAdvancedButton(isOpen: viewModel.showsAdvanced) { viewModel.showsAdvanced.toggle() }
            if viewModel.showsAdvanced {
                advanced(effect)
            }
        }
        .task { await viewModel.checkBackgroundSupport() }
    }

    /// Only for a clip, and only once it sets its own background: back to its recording's.
    private var reset: (() -> Void)? {
        guard viewModel.clipOverridesBackground else { return nil }
        return { viewModel.resetClipBackground() }
    }

    @ViewBuilder
    private func advanced(_ effect: BackgroundEffect) -> some View {
        if effect.style == .blur {
            slider(String(localized: "Blur strength"), value: effect.blur, range: BackgroundEffect.blurRange, identifier: "edit.backgroundBlur") { value in
                viewModel.updateBackground { $0.blur = value }
            }
        }
        PanelToggleRow(
            label: String(localized: "Color key"), detail: String(localized: "Remove a green or blue screen"),
            isOn: effect.cutout == .colorKey, identifier: "edit.backgroundColorKey"
        ) { viewModel.setBackgroundCutout(effect.cutout == .colorKey ? .person : .colorKey) }
        if effect.cutout == .colorKey {
            PanelSegmented(
                label: String(localized: "Key color"),
                options: [PanelOption("green", String(localized: "Green screen")), PanelOption("blue", String(localized: "Blue screen"))],
                selection: Self.screen(of: effect.key), identifier: "edit.keyColor"
            ) { name in
                let preset = name == "blue" ? ChromaKey.blue : ChromaKey.green
                viewModel.setKeyColor(red: preset.red, green: preset.green, blue: preset.blue)
            }
            ColorPicker(selection: Binding(
                get: { Color(red: effect.key.red, green: effect.key.green, blue: effect.key.blue) },
                set: { color in
                    let parts = Self.components(of: color)
                    viewModel.setKeyColor(red: parts.red, green: parts.green, blue: parts.blue)
                }
            ), supportsOpacity: false) {
                Text("Pick the screen's color").font(.system(.subheadline, weight: .semibold))
            }
            .frame(minHeight: Metrics.hitTarget)
            .accessibilityIdentifier("edit.keyColorPicker")
            slider(String(localized: "Tolerance"), value: effect.key.tolerance, range: 0...1, identifier: "edit.keyTolerance") { value in
                viewModel.updateBackground { $0.key.tolerance = value }
            }
            slider(String(localized: "Edge"), value: effect.key.softness, range: 0...1, identifier: "edit.keySoftness") { value in
                viewModel.updateBackground { $0.key.softness = value }
            }
            slider(String(localized: "Spill"), value: effect.key.spill, range: 0...1, identifier: "edit.keySpill") { value in
                viewModel.updateBackground { $0.key.spill = value }
            }
        }
    }

    private func slider(
        _ label: String, value: Double, range: ClosedRange<Double>, identifier: String, set: @escaping (Double) -> Void
    ) -> some View {
        PanelSlider(
            label: label, value: value * 100, range: range.lowerBound * 100...range.upperBound * 100, format: .percent,
            identifier: identifier, onChange: { set($0 / 100) },
            onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
        )
    }

    /// "green" or "blue" for the two screens' colors; nil for a color picked by hand.
    private static func screen(of key: ChromaKey) -> String? {
        func matches(_ preset: ChromaKey) -> Bool {
            abs(key.red - preset.red) < 0.001 && abs(key.green - preset.green) < 0.001 && abs(key.blue - preset.blue) < 0.001
        }
        if matches(.green) { return "green" }
        return matches(.blue) ? "blue" : nil
    }

    /// sRGB components of a picked color, 0 to 1.
    private static func components(of color: Color) -> (red: Double, green: Double, blue: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func clamped(_ value: CGFloat) -> Double { min(max(Double(value), 0), 1) }
        return (clamped(red), clamped(green), clamped(blue))
    }
}
