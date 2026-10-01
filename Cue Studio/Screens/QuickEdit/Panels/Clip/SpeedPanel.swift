//
//  SpeedPanel.swift
//  Cue Studio
//

import SwiftUI

/// Speed (this clip): 0.5× to 2× in one tap, the picked one in yellow. With one clip, "Split at
/// playhead to change one part". Advanced: any speed from 0.25× to 4× and "Keep voice pitch".
struct SpeedPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let clip = viewModel.targetClip
        let speed = clip?.speed ?? 1
        PanelFrame(viewModel: viewModel, panel: .speed) {
            PanelSegmented(
                options: QuickEditViewModel.quickSpeeds.map { PanelOption($0, Self.label($0), key: Self.key($0)) },
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
            PanelAdvancedButton(isOpen: viewModel.showsAdvanced) { viewModel.showsAdvanced.toggle() }
            if viewModel.showsAdvanced {
                PanelSlider(
                    label: String(localized: "Custom speed"), value: speed, range: EditSegment.speedRange, step: 0.05,
                    format: .speed, identifier: "edit.speed.custom"
                ) { viewModel.setClipSpeed($0) }
                PanelToggleRow(
                    label: String(localized: "Keep voice pitch"), detail: String(localized: "No chipmunk effect when sped up"),
                    isOn: clip?.keepsPitch ?? true, identifier: "edit.speed.keepPitch"
                ) { viewModel.setKeepsPitch(!(clip?.keepsPitch ?? true)) }
            }
        }
    }

    static func label(_ speed: Double) -> String {
        speed.formatted(.number.precision(.fractionLength(0...2)).locale(.interface)) + "×"
    }

    static func key(_ speed: Double) -> String {
        String(format: "%.2f", speed)
    }
}
