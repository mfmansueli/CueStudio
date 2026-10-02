//
//  AdjustPanel.swift
//  Cue Studio
//

import SwiftUI

/// Adjust (whole take): Auto, then one ruler for the setting picked in a row of dials (Exposure,
/// Contrast, Warmth, Saturation, Highlights, Shadows, Sharpness), each showing its value; a dial
/// that is off zero is yellow. Reset puts them all back, and the setting on the ruler has its own.
struct AdjustPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @State private var current: QuickEditViewModel.Adjustment = .exposure

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .adjust, onReset: reset) {
            PanelButton(label: String(localized: "Auto"), systemImage: "sparkles", identifier: "edit.adjust.auto", action: viewModel.autoAdjust)
            dials
            readout
            PanelRulerSlider(
                label: current.label, value: viewModel.adjustment(current), range: range(of: current), bipolar: current.isBipolar,
                format: format(of: current), identifier: "edit.adjust.ruler",
                onChange: { viewModel.setAdjustment(current, $0) }
            )
        }
    }

    private var reset: (() -> Void)? {
        guard viewModel.hasAdjustments else { return nil }
        return { viewModel.resetAdjustments() }
    }

    private func range(of adjustment: QuickEditViewModel.Adjustment) -> ClosedRange<Double> {
        adjustment.isBipolar ? TakeEdit.adjustmentRange : 0...100
    }

    private func format(of adjustment: QuickEditViewModel.Adjustment) -> PanelValueFormat {
        adjustment.isBipolar ? .signed : .plain
    }

    // MARK: - Pieces

    private var dials: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(QuickEditViewModel.Adjustment.allCases) { adjustment in
                    dial(adjustment)
                }
            }
        }
        .scrollIndicators(.hidden)
        // The row runs to the panel's edges, so a dial doesn't stop short of them when it scrolls.
        .padding(.horizontal, -16)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }

    private func dial(_ adjustment: QuickEditViewModel.Adjustment) -> some View {
        let isPicked = adjustment == current
        let value = viewModel.adjustment(adjustment)
        let isChanged = value != 0
        let ink: Color = isPicked ? Palette.accInk : isChanged ? Palette.acc : Palette.ink
        let ring: Color = isPicked ? .white : isChanged ? Palette.acc : Palette.adjustDialRing
        return Button {
            current = adjustment
        } label: {
            VStack(spacing: 6) {
                Text(format(of: adjustment).text(value))
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(ink)
                    .frame(width: 48, height: 48)
                    .background(isPicked ? Color.white : Color.clear, in: Circle())
                    .overlay(Circle().strokeBorder(ring, lineWidth: 2))
                Text(adjustment.label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(isPicked ? Palette.ink : Palette.ink2)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minWidth: 64, minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(adjustment.label))
        .accessibilityValue(Text(format(of: adjustment).text(value)))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
        .accessibilityIdentifier("edit.adjust.\(adjustment.rawValue)")
    }

    /// "Exposure  +10" with its own Reset once it is off zero.
    private var readout: some View {
        let value = viewModel.adjustment(current)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(current.label).font(.system(.subheadline, weight: .semibold))
            Text(format(of: current).text(value))
                .font(.system(.subheadline, weight: .bold).monospacedDigit())
                .foregroundStyle(Palette.accText)
            if value != 0 {
                Button("Reset") { viewModel.setAdjustment(current, 0) }
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .buttonStyle(.plain)
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
                    .accessibilityLabel(Text("Reset"))
                    .accessibilityValue(Text(current.label))
                    .accessibilityIdentifier("edit.adjust.resetOne")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22)
    }
}
