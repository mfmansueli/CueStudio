//
//  AdjustPanel.swift
//  Cue Studio
//

import SwiftUI

/// Adjust (whole take): Auto, Exposure, Contrast and Warmth filled from the middle; Saturation,
/// Highlights, Shadows and Sharpness under Advanced; Reset.
struct AdjustPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .adjust, onReset: reset) {
            PanelButton(label: String(localized: "Auto"), systemImage: "sparkles", identifier: "edit.adjust.auto", action: viewModel.autoAdjust)
            ForEach(QuickEditViewModel.Adjustment.allCases.filter { !$0.isAdvanced }) { adjustment in
                slider(adjustment)
            }
            PanelAdvancedButton(isOpen: viewModel.showsAdvanced) { viewModel.showsAdvanced.toggle() }
            if viewModel.showsAdvanced {
                ForEach(QuickEditViewModel.Adjustment.allCases.filter(\.isAdvanced)) { adjustment in
                    slider(adjustment)
                }
            }
        }
    }

    private var reset: (() -> Void)? {
        guard viewModel.hasAdjustments else { return nil }
        return { viewModel.resetAdjustments() }
    }

    private func slider(_ adjustment: QuickEditViewModel.Adjustment) -> some View {
        PanelSlider(
            label: adjustment.label, value: viewModel.adjustment(adjustment),
            range: adjustment.isBipolar ? TakeEdit.adjustmentRange : 0...100, bipolar: adjustment.isBipolar,
            format: adjustment.isBipolar ? .signed : .plain, identifier: "edit.adjust.\(adjustment.rawValue)"
        ) { viewModel.setAdjustment(adjustment, $0) }
    }
}
