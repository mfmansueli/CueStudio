//
//  BackgroundToolView.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI
import UIKit

/// Background: for the recording under the playhead, who is kept (the person, found on the iPhone,
/// or everything but a green or blue screen) and what goes behind (Original, Blur, Color, Image),
/// with the blur's strength, the color, the photo, or the key's color, tolerance, edge and spill.
/// Without person detection on this iPhone, it says so and the color key still works.
struct BackgroundToolView: View {
    let viewModel: QuickEditViewModel

    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        let effect = viewModel.currentBackground
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.backgroundTargetTitle).font(.subheadline.weight(.semibold))
                    Text("Every section of this recording · your recording stays untouched")
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                }
                Picker("Keep", selection: Binding(get: { effect.cutout }, set: { viewModel.setBackgroundCutout($0) })) {
                    ForEach(BackgroundCutout.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("edit.backgroundCutout")
                if effect.cutout == .person, viewModel.canFindPeople == false {
                    Text("This iPhone can’t find people in video. Use a color key with a green or blue screen.")
                        .font(.footnote)
                        .foregroundStyle(Palette.warn)
                        .accessibilityIdentifier("edit.backgroundUnavailable")
                }
                styleChips(effect)
                details(effect)
                if effect.cutout == .colorKey {
                    keyControls(effect.key)
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .task { await viewModel.checkBackgroundSupport() }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await viewModel.importBackgroundImage(item) }
        }
    }

    private func styleChips(_ effect: BackgroundEffect) -> some View {
        HStack(spacing: 6) {
            ForEach(BackgroundStyle.allCases) { style in
                let isOn = effect.style == style
                Button { viewModel.setBackgroundStyle(style) } label: {
                    FilterChip(label: style.label, isSelected: isOn, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("edit.background.\(style.rawValue)")
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func details(_ effect: BackgroundEffect) -> some View {
        switch effect.style {
        case .original:
            EmptyView()
        case .blur:
            slider(String(localized: "Strength"), value: effect.blur, range: BackgroundEffect.blurRange, identifier: "edit.backgroundBlur") { value in
                viewModel.updateBackground { $0.blur = value }
            }
        case .color:
            HStack(spacing: 10) {
                ForEach(OverlayColor.allCases) { color in
                    SwatchButton(color: color.color, isSelected: effect.color == color, accessibilityName: color.label) {
                        viewModel.updateBackground { $0.color = color }
                    }
                }
            }
            .accessibilityIdentifier("edit.backgroundColor")
        case .image:
            PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 8) {
                    if viewModel.isImportingBackground {
                        ProgressView().tint(Palette.bg)
                    } else {
                        Image(systemName: "photo")
                    }
                    effect.imageFileName == nil ? Text("Choose a photo") : Text("Change photo")
                }
            }
            .buttonStyle(.cueLight(.medium))
            .disabled(viewModel.isImportingBackground)
            .accessibilityIdentifier("edit.backgroundPhotoButton")
        }
    }

    private func keyControls(_ key: ChromaKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                keyChip(String(localized: "Green screen"), preset: .green, current: key)
                keyChip(String(localized: "Blue screen"), preset: .blue, current: key)
                ColorPicker(selection: Binding(
                    get: { Color(red: key.red, green: key.green, blue: key.blue) },
                    set: { color in
                        let parts = Self.components(of: color)
                        viewModel.setKeyColor(red: parts.red, green: parts.green, blue: parts.blue)
                    }
                ), supportsOpacity: false) {
                    Text("Key color").font(.footnote)
                }
                .accessibilityIdentifier("edit.keyColor")
            }
            slider(String(localized: "Tolerance"), value: key.tolerance, range: 0...1, identifier: "edit.keyTolerance") { value in
                viewModel.updateBackground { $0.key.tolerance = value }
            }
            slider(String(localized: "Edge"), value: key.softness, range: 0...1, identifier: "edit.keySoftness") { value in
                viewModel.updateBackground { $0.key.softness = value }
            }
            slider(String(localized: "Spill"), value: key.spill, range: 0...1, identifier: "edit.keySpill") { value in
                viewModel.updateBackground { $0.key.spill = value }
            }
        }
    }

    /// sRGB components of a picked color, 0 to 1.
    private static func components(of color: Color) -> (red: Double, green: Double, blue: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func clamped(_ value: CGFloat) -> Double { min(max(Double(value), 0), 1) }
        return (clamped(red), clamped(green), clamped(blue))
    }

    private func keyChip(_ title: String, preset: ChromaKey, current: ChromaKey) -> some View {
        let isOn = abs(current.red - preset.red) < 0.001 && abs(current.green - preset.green) < 0.001 && abs(current.blue - preset.blue) < 0.001
        return Button { viewModel.setKeyColor(red: preset.red, green: preset.green, blue: preset.blue) } label: {
            FilterChip(label: title, isSelected: isOn, dotColor: Color(red: preset.red, green: preset.green, blue: preset.blue), height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func slider(
        _ title: String, value: Double, range: ClosedRange<Double>, identifier: String, set: @escaping (Double) -> Void
    ) -> some View {
        let text = value.formatted(.percent.precision(.fractionLength(0)).locale(.interface))
        return HStack(spacing: 10) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .frame(minWidth: 72, alignment: .leading)
            Slider(
                value: Binding(get: { value }, set: set), in: range,
                onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
            )
            .tint(Palette.acc)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(text))
            .accessibilityIdentifier(identifier)
            Text(text)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Palette.ink2)
                .fixedSize()
                .frame(minWidth: 44, alignment: .trailing)
        }
    }
}
