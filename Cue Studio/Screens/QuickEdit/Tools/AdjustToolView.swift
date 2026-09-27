//
//  AdjustToolView.swift
//  Cue Studio
//

import SwiftUI

/// Adjust: exposure, contrast and warmth from −100 to +100, with Auto.
struct AdjustToolView: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button(action: viewModel.autoAdjust) {
                Label("Auto", systemImage: "sparkles")
            }
            .buttonStyle(.cueTinted(.compact, expands: false))
            .accessibilityIdentifier("edit.autoButton")
            VStack(spacing: 0) {
                slider(String(localized: "Exposure"), value: $viewModel.edit.exposure)
                slider(String(localized: "Contrast"), value: $viewModel.edit.contrast)
                slider(String(localized: "Warmth"), value: $viewModel.edit.warmth)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        }
    }

    private func slider(_ title: String, value: Binding<Double>) -> some View {
        let number = Int(value.wrappedValue.rounded())
        return ValueSlider(
            title: title,
            valueText: number > 0 ? "+\(number)" : "\(number)",
            value: value,
            range: TakeEdit.adjustmentRange
        )
    }
}
