//
//  AdjustPanel.swift
//  Cue Studio
//

import SwiftUI

/// Adjust (whole take, or the picked clip alone when opened from it): one ruler for the setting picked in a row of dials (Exposure, Contrast,
/// Warmth, Saturation, Highlights, Shadows, Sharpness), each showing its value; a dial that is off
/// zero is yellow; for a clip a dial shows the take's value until the clip sets its own, and Reset
/// gives the clip the take's values again. Auto sits on the line of the picked setting's name and value, so the controls
/// fit the panel without scrolling on an ordinary iPhone. Reset puts them all back, and the setting
/// on the ruler has its own.
struct AdjustPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @State private var current: QuickEditViewModel.Adjustment = .exposure

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .adjust, onReset: reset) {
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

    /// "Exposure  +10" with its own Reset once it is off zero, and Auto at the other end.
    private var readout: some View {
        let value = viewModel.adjustment(current)
        return HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(current.label).font(.system(.subheadline, weight: .semibold))
                Text(format(of: current).text(value))
                    .font(.system(.subheadline, weight: .bold).monospacedDigit())
                    .foregroundStyle(Palette.accText)
            }
            .accessibilityElement(children: .combine)
            if let note = inheritedNote {
                Text(note)
                    .font(.system(.footnote))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if viewModel.canResetAdjustment(current) {
                Button("Reset") { viewModel.resetAdjustment(current) }
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .buttonStyle(.plain)
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
                    .accessibilityLabel(Text("Reset"))
                    .accessibilityValue(Text(current.label))
                    .accessibilityIdentifier("edit.adjust.resetOne")
            }
            Spacer(minLength: 0)
            autoButton
        }
        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
    }

    /// For a clip, where the dial's value comes from while the clip hasn't set it.
    private var inheritedNote: String? {
        guard viewModel.lookClip != nil, !viewModel.clipOverrides(current) else { return nil }
        return String(localized: "From the whole take")
    }

    private var autoButton: some View {
        Button(action: viewModel.autoAdjust) {
            Label("Auto", systemImage: "sparkles")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: Metrics.hitTarget)
                .background(Palette.fill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("edit.adjust.auto")
    }
}
