//
//  BackgroundPanel.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Background (the recording under the playhead, or the picked clip alone when opened from it; the file never changes). The header says
/// what it changes and what is behind the creator now ("Whole video · Blur behind you"); a note under it tells the scope's rule when there
/// is one (a clip with its own background, which Reset gives back to the take's). Then two parts, kept apart:
///
/// - **Behind you**: Original, Blur, Color or Image, and right under them only the picked one's control (the blur's strength, the colors,
///   the photo).
/// - **Cutout**, in its own card: how the background is told apart from the creator. Automatic (Vision finds the person on the iPhone) or
///   a green or blue screen (a chroma key), with the screen's color and, folded under "Fine-tune the cutout", Tolerance, Edge and Spill.
///
/// Every value stays while another option or mode is picked, every change is an undo step and is saved as it's made; ✓ closes.
struct BackgroundPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let effect = viewModel.currentBackground
        PanelFrame(viewModel: viewModel, panel: .background, onReset: reset, compare: viewModel.pictureCompare) {
            if let note = viewModel.backgroundScopeNote { scopeNote(note) }
            background(effect)
            cutout(effect)
            PanelNote(text: String(localized: "Changes show in the preview and are saved as you make them. ✓ closes the panel."))
                .accessibilityIdentifier("edit.backgroundSaveNote")
        }
        .task { await viewModel.checkBackgroundSupport() }
    }

    /// Only for a clip, and only once it sets its own background: back to its recording's.
    private var reset: (() -> Void)? {
        guard viewModel.clipOverridesBackground else { return nil }
        return { viewModel.resetClipBackground() }
    }

    // MARK: - Scope

    private func scopeNote(_ note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: viewModel.lookClip == nil ? "film" : "rectangle.split.3x1")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
            Text(note)
                .font(.system(.footnote))
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("edit.backgroundScope")
    }

    // MARK: - Background

    /// The four backgrounds, and under them the picked one's control only.
    private func background(_ effect: BackgroundEffect) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelRowLabel(label: String(localized: "Behind you"))
                .accessibilityAddTraits(.isHeader)
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
            switch effect.style {
            case .original:
                PanelNote(text: String(localized: "Your video as you recorded it. Pick Blur, Color or Image to change what's behind you."))
            case .blur:
                slider(String(localized: "Blur strength"), value: effect.blur, range: BackgroundEffect.blurRange, identifier: "edit.backgroundBlur") { value in
                    viewModel.updateBackground { $0.blur = value }
                }
            case .color:
                PanelSwatches(
                    label: String(localized: "Color"), colors: OverlayColor.palette, selection: effect.color,
                    identifier: "edit.backgroundColor"
                ) { color in viewModel.updateBackground { $0.color = color } }
            case .image:
                PanelButton(
                    label: viewModel.isImportingBackground
                        ? String(localized: "Adding…")
                        : (effect.imageFileName == nil ? String(localized: "Choose a photo") : String(localized: "Change photo")),
                    systemImage: "photo", isEnabled: !viewModel.isImportingBackground, identifier: "edit.backgroundPhotoButton"
                ) { viewModel.requestPhoto(.background) }
            }
        }
    }

    // MARK: - Cutout

    /// How the background is told apart from the creator, in a card of its own: secondary to the background itself.
    private func cutout(_ effect: BackgroundEffect) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelRowLabel(
                label: String(localized: "Cutout"),
                detail: effect.style == .original ? String(localized: "Used once a background is picked") : nil
            )
            .accessibilityAddTraits(.isHeader)
            PanelSegmented(
                options: [
                    PanelOption(BackgroundCutout.person, String(localized: "Automatic")),
                    PanelOption(BackgroundCutout.colorKey, String(localized: "Green or blue screen")),
                ],
                selection: effect.cutout, height: 38, identifier: "edit.backgroundCutout"
            ) { cutout in viewModel.setBackgroundCutout(cutout) }
            switch effect.cutout {
            case .person:
                PanelNote(text: String(localized: "Cue finds you in every frame, on this iPhone, and changes everything around you."))
                if effect.style != .original, viewModel.canFindPeople == false {
                    PanelNote(text: String(localized: "Can't find people here · Use a green or blue screen"), tint: Palette.warnText)
                        .accessibilityIdentifier("edit.backgroundUnavailable")
                }
            case .colorKey:
                PanelNote(text: String(localized: "For a video recorded in front of a green or blue screen: only the screen's color is replaced."))
                screenColor(effect.key)
                PanelAdvancedButton(
                    isOpen: viewModel.showsAdvanced, title: String(localized: "Fine-tune the cutout"),
                    detail: viewModel.backgroundKeyIsAdjusted ? String(localized: "· adjusted") : nil,
                    identifier: "edit.backgroundFineTune"
                ) { viewModel.showsAdvanced.toggle() }
                if viewModel.showsAdvanced { fineTune(effect.key) }
            }
        }
        .padding(12)
        .background(Palette.Editor.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.backgroundCutoutCard")
    }

    /// The screen behind the creator: green, blue, or a color picked from the video's own screen.
    @ViewBuilder
    private func screenColor(_ key: ChromaKey) -> some View {
        PanelSegmented(
            label: String(localized: "Screen color"),
            detail: Self.screen(of: key) == nil ? String(localized: "Your own color") : nil,
            options: [PanelOption("green", String(localized: "Green screen")), PanelOption("blue", String(localized: "Blue screen"))],
            selection: Self.screen(of: key), identifier: "edit.keyColor"
        ) { name in
            let preset = name == "blue" ? ChromaKey.blue : ChromaKey.green
            viewModel.setKeyColor(red: preset.red, green: preset.green, blue: preset.blue)
        }
        ColorPicker(selection: Binding(
            get: { Color(red: key.red, green: key.green, blue: key.blue) },
            set: { color in
                let parts = Self.components(of: color)
                viewModel.setKeyColor(red: parts.red, green: parts.green, blue: parts.blue)
            }
        ), supportsOpacity: false) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pick the screen's color").font(.system(.subheadline, weight: .semibold))
                Text("When your screen isn't a standard green or blue").font(.system(.caption)).foregroundStyle(Palette.ink2)
            }
        }
        .frame(minHeight: Metrics.hitTarget)
        .accessibilityIdentifier("edit.keyColorPicker")
    }

    /// Tolerance, Edge and Spill, each with what it really does.
    private func fineTune(_ key: ChromaKey) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            described(String(localized: "More removes shades of the screen that are further from its color.")) {
                slider(String(localized: "Tolerance"), value: key.tolerance, range: 0...1, identifier: "edit.keyTolerance") { value in
                    viewModel.updateBackground { $0.key.tolerance = value }
                }
            }
            described(String(localized: "How soft the outline between you and the new background is.")) {
                slider(String(localized: "Edge"), value: key.softness, range: 0...1, identifier: "edit.keySoftness") { value in
                    viewModel.updateBackground { $0.key.softness = value }
                }
            }
            described(String(localized: "Takes the screen's tint off you: the green or blue it reflects on skin, hair and clothes.")) {
                slider(String(localized: "Spill"), value: key.spill, range: 0...1, identifier: "edit.keySpill") { value in
                    viewModel.updateBackground { $0.key.spill = value }
                }
            }
        }
    }

    private func described(_ note: String, @ViewBuilder _ control: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            control()
            PanelNote(text: note)
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
