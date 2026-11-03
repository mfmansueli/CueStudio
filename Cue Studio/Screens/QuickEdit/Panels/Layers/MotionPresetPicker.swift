//
//  MotionPresetPicker.swift
//  Cue Studio
//

import SwiftUI

/// Motion's ready-made ways in (and out) for the picked text or photo or video: None, Fade in, Slide up, Slide in, Gentle zoom,
/// Pop, In and out; with one picked, how long it takes and how strong it is ("Preview" in the panel's header plays it,
/// `PanelPlay.motion`). They sit over the keyframes, which stay for moving it by hand (under them). A text that wears an
/// effect also has "Effect's own" after None, one of them picked at a time: the effect's way in and out as its card shows,
/// or a Motion (or None) with the effect still, keeping its finish.
struct MotionPresetPicker: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        let overlays = viewModel.overlays
        let current = overlays.selectedAnimation
        let effect = overlays.selectedTextID != nil ? overlays.selectedText?.effect : nil
        let effectMoves = effect?.isAnimated == true && current == nil
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    tile(String(localized: "None"), systemImage: "nosign", key: "none", isOn: current == nil && !effectMoves) {
                        overlays.setMotionPreset(nil)
                    }
                    if effect != nil {
                        tile(Self.effectsOwn, systemImage: "sparkles", key: "effect", isOn: effectMoves, action: overlays.playEffectsOwnMotion)
                    }
                    ForEach(MotionPreset.allCases) { preset in
                        tile(preset.label, systemImage: preset.systemImage, key: preset.rawValue, isOn: current?.preset == preset) {
                            overlays.setMotionPreset(preset)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
            if effect != nil, current != nil {
                PanelNote(text: String(localized: "The effect keeps its finish; this Motion plays instead of its own way in and out."))
                    .accessibilityIdentifier("edit.motion.effectNote")
            }
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
            }
        }
    }

    private static var effectsOwn: String {
        String(localized: "Effect's own", comment: "Motion: the text effect's own way in and out, in place of None")
    }

    private func tile(_ label: String, systemImage: String, key: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.editorGlyph(EditorGlyph.tool, weight: .semibold))
                // Two lines broken between words, never inside one (owner, 02/11/2026: no label is ever cut).
                WholeWordsLabel(text: label, minimumScale: 0.8).font(.system(.caption, weight: .semibold))
            }
            .foregroundStyle(isOn ? Palette.accText : Palette.ink)
            .frame(width: 76, height: 70)
            .editorCard(isOn ? .picked : .plain)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePressCard)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("edit.motion.preset.\(key)")
    }
}
