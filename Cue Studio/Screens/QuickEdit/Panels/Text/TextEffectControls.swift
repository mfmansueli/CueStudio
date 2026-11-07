//
//  TextEffectControls.swift
//  Cue Studio
//

import SwiftUI

/// Text style › Styles, under the animated cards, for a text that wears an effect: whether it plays its way in and out
/// (Animated, which takes a Motion off the text) or keeps its finish still, its own strength (named for what it changes:
/// Shine, Depth, Glow…), how long its way in takes and which way it goes, and Remove effect (▶ PREVIEW in the panel's
/// header plays the text's first seconds on the video, as it will export). Only what the effect uses shows; its colors are
/// Color tab's.
struct TextEffectControls: View {
    let viewModel: QuickEditViewModel
    let effect: TextEffect

    var body: some View {
        let overlays = viewModel.overlays
        let kind = effect.kind
        PanelSegmented(
            label: String(localized: "Effect motion"), options: TextEffectMotion.allCases.map { PanelOption($0, $0.label) },
            selection: effect.motion, height: 38, identifier: "edit.textEffect.motion"
        ) { overlays.restyleText(.effectMotion($0)) }
        PanelSlider(
            label: kind.intensityLabel, value: (effect.intensity * 100).rounded(), range: CueSliderSpec.effectStrength.range,
            step: CueSliderSpec.effectStrength.step ?? 5, defaultValue: (kind.defaultIntensity * 100).rounded(), format: .percent,
            identifier: "edit.textEffect.intensity"
        ) { overlays.restyleText(.effectIntensity($0 / 100), key: "effectIntensity") }
        if effect.isAnimated {
            PanelSlider(
                label: String(localized: "Duration"), value: effect.duration, range: CueSliderSpec.effectDuration.range,
                step: CueSliderSpec.effectDuration.step ?? 0.1, defaultValue: kind.defaultDuration, format: .seconds,
                identifier: "edit.textEffect.duration"
            ) { overlays.restyleText(.effectDuration($0), key: "effectDuration") }
        }
        // Pop 3D's direction is its depth's, so it stays with a still effect.
        if kind.directions.count > 1, effect.isAnimated || kind == .pop3D {
            PanelSegmented(
                label: kind == .pop3D ? String(localized: "Depth direction") : String(localized: "Direction"),
                options: kind.directions.map { PanelOption($0, $0.label(for: kind)) },
                selection: effect.direction, height: 38, identifier: "edit.textEffect.direction"
            ) { overlays.restyleText(.effectDirection($0)) }
        }
        PanelButton(
            label: String(localized: "Remove effect"), systemImage: "xmark", isCompact: true, identifier: "edit.textEffect.remove"
        ) { overlays.restyleText(.removeEffect) }
    }
}
