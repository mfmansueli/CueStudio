//
//  SpeedPanel.swift
//  Cue Studio
//

import SwiftUI

/// Speed (this clip): Normal (0.5× to 2× in one tap, the picked one in yellow; with one clip, "Split at playhead to change one
/// part"; Advanced: any speed from 0.5× to 3×) or Curve (ready-made curves drawn as they play, and the curve to shape by its
/// points). "Keep voice pitch" for both.
struct SpeedPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let clip = viewModel.targetClip
        let speed = clip?.speed ?? 1
        PanelFrame(viewModel: viewModel, panel: .speed) {
            PanelSegmented(
                options: [PanelOption(false, String(localized: "Normal"), key: "normal"), PanelOption(true, String(localized: "Curve"), key: "curve")],
                selection: viewModel.showsCurveTab, identifier: "edit.speed.mode"
            ) { viewModel.showSpeedCurves($0) }
            if viewModel.showsCurveTab {
                SpeedCurvePanel(viewModel: viewModel)
            } else {
                normal(speed: speed)
            }
            PanelToggleRow(
                label: String(localized: "Keep voice pitch"), detail: String(localized: "No chipmunk effect when sped up"),
                isOn: clip?.keepsPitch ?? true, identifier: "edit.speed.keepPitch"
            ) { viewModel.setKeepsPitch(!(clip?.keepsPitch ?? true)) }
        }
    }

    @ViewBuilder
    private func normal(speed: Double) -> some View {
        PanelSegmented(
            options: QuickEditViewModel.quickSpeeds.map { PanelOption($0, SpeedScale.label(forMultiple: $0), key: Self.key($0)) },
            selection: QuickEditViewModel.quickSpeeds.first { abs($0 - speed) < 0.001 },
            accent: true, identifier: "edit.speed"
        ) { viewModel.setClipSpeed($0) }
        if viewModel.edit.timeline.segments.count == 1 {
            PanelButton(
                label: String(localized: "Split at playhead to change one part"),
                systemImage: "arrow.left.and.line.vertical.and.arrow.right", identifier: "edit.speed.split",
                action: viewModel.splitToChangeOnePart
            )
        }
        PanelAdvancedButton(
            isOpen: viewModel.showsAdvanced,
            detail: QuickEditViewModel.quickSpeeds.contains { abs($0 - speed) < 0.001 } ? nil : PanelAdvancedButton.changed(1)
        ) { viewModel.showsAdvanced.toggle() }
        if viewModel.showsAdvanced {
            PanelSlider(
                label: String(localized: "Custom speed"), value: speed, range: CueSliderSpec.clipSpeed.range,
                step: CueSliderSpec.clipSpeed.step ?? 0.1, defaultValue: CueSliderSpec.clipSpeed.defaultValue,
                format: .speed, identifier: "edit.speed.custom"
            ) { viewModel.setClipSpeed($0) }
        }
    }

    static func key(_ speed: Double) -> String {
        String(format: "%.2f", speed)
    }
}
