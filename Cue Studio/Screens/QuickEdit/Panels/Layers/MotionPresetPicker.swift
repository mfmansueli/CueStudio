//
//  MotionPresetPicker.swift
//  Cue Studio
//

import SwiftUI

/// Motion's ready-made ways in (and out) for the picked text or photo or video: None, Fade in, Slide up, Slide in, Gentle zoom,
/// Pop, In and out; with one picked, how long it takes and how strong it is, and Play to see it. They sit over the keyframes,
/// which stay for moving it by hand (under them).
struct MotionPresetPicker: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        let current = viewModel.overlays.selectedAnimation
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    tile(nil, label: String(localized: "None"), systemImage: "nosign", isOn: current == nil)
                    ForEach(MotionPreset.allCases) { preset in
                        tile(preset, label: preset.label, systemImage: preset.systemImage, isOn: current?.preset == preset)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
            if let current {
                PanelSlider(
                    label: current.preset.spansTheWholeItem ? String(localized: "Ease in") : String(localized: "Duration"),
                    value: current.duration, range: OverlayAnimation.durationRange, step: 0.1, defaultValue: 0.5, format: .seconds,
                    identifier: "edit.motion.duration", onChange: { viewModel.overlays.setMotionDuration($0) }
                )
                PanelSlider(
                    label: String(localized: "Strength"), value: current.intensity * 100, range: 0...100, step: 5, defaultValue: 50,
                    format: .percent, identifier: "edit.motion.intensity", onChange: { viewModel.overlays.setMotionIntensity($0 / 100) }
                )
                PanelButton(label: String(localized: "Play it"), systemImage: "play.fill", identifier: "edit.motion.play") {
                    viewModel.overlays.previewMotion()
                }
            }
        }
    }

    private func tile(_ preset: MotionPreset?, label: String, systemImage: String, isOn: Bool) -> some View {
        Button { viewModel.overlays.setMotionPreset(preset) } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.editorGlyph(EditorGlyph.tool, weight: .semibold))
                Text(label).font(.system(.caption, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
            }
            .foregroundStyle(isOn ? Palette.accText : Palette.ink)
            .frame(width: 76, height: 70)
            .editorCard(isOn ? .picked : .plain)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePressCard)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("edit.motion.preset.\(preset?.rawValue ?? "none")")
    }
}
