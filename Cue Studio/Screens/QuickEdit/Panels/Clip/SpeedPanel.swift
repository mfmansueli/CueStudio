//
//  SpeedPanel.swift
//  Cue Studio
//

import SwiftUI

/// Speed (this clip): Normal (0.5× to 2× in one tap, the picked one in yellow; with one clip, "Split at playhead to change one
/// part"; "Keep voice pitch"; Advanced: any speed from 0.5× to 3×) or Curve (ready-made curves drawn as they play, the curve
/// to shape by its points, then "Keep voice pitch"). Normal | Curve only switches the view; a speed picked in Normal replaces
/// a curve (none is lit then, so even 1× can be picked). Off 1×, "Preview" in the header plays the clip's first seconds as they play now.
struct SpeedPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let clip = viewModel.targetClip
        let speed = clip?.speed ?? 1
        let play = viewModel.clips.canPreviewSpeed ? PanelPlay(action: viewModel.clips.previewSpeed) : nil
        PanelFrame(viewModel: viewModel, panel: .speed, play: play) {
            PanelSegmented(
                options: [PanelOption(false, String(localized: "Normal"), key: "normal"), PanelOption(true, String(localized: "Curve"), key: "curve")],
                selection: viewModel.clips.showsCurveTab, identifier: "edit.speed.mode"
            ) { viewModel.clips.showSpeedCurves($0) }
            if viewModel.clips.showsCurveTab {
                SpeedCurvePanel(viewModel: viewModel)
                keepsPitch(clip)
            } else {
                normal(speed: speed, hasCurve: clip?.speedCurve != nil)
            }
        }
    }

    private func keepsPitch(_ clip: EditSegment?) -> some View {
        PanelToggleRow(
            label: String(localized: "Keep voice pitch"), detail: String(localized: "No chipmunk effect when sped up"),
            isOn: clip?.keepsPitch ?? true, identifier: "edit.speed.keepPitch"
        ) { viewModel.clips.setKeepsPitch(!(clip?.keepsPitch ?? true)) }
    }

    @ViewBuilder
    private func normal(speed: Double, hasCurve: Bool) -> some View {
        PanelSegmented(
            options: ClipsViewModel.quickSpeeds.map { PanelOption($0, SpeedScale.label(forMultiple: $0), key: Self.key($0)) },
            selection: hasCurve ? nil : ClipsViewModel.quickSpeeds.first { abs($0 - speed) < 0.001 },
            accent: true, identifier: "edit.speed"
        ) { viewModel.clips.setClipSpeed($0) }
        if viewModel.edit.timeline.segments.count == 1 {
            PanelButton(
                label: String(localized: "Split at playhead to change one part"),
                systemImage: "arrow.left.and.line.vertical.and.arrow.right", identifier: "edit.speed.split",
                action: viewModel.clips.splitToChangeOnePart
            )
        }
        keepsPitch(viewModel.targetClip)
        PanelAdvancedButton(
            isOpen: viewModel.showsAdvanced,
            detail: ClipsViewModel.quickSpeeds.contains { abs($0 - speed) < 0.001 } ? nil : PanelAdvancedButton.changed(1)
        ) { viewModel.showsAdvanced.toggle() }
        if viewModel.showsAdvanced {
            PanelSlider(
                label: String(localized: "Custom speed"), value: speed, range: CueSliderSpec.clipSpeed.range,
                step: CueSliderSpec.clipSpeed.step ?? 0.1, defaultValue: CueSliderSpec.clipSpeed.defaultValue,
                format: .speed, identifier: "edit.speed.custom"
            ) { viewModel.clips.setClipSpeed($0) }
        }
    }

    static func key(_ speed: Double) -> String {
        String(format: "%.2f", speed)
    }
}
