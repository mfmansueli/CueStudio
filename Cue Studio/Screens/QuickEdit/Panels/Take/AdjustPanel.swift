//
//  AdjustPanel.swift
//  Cue Studio
//

import SwiftUI

/// Adjust (whole take, or the picked clip alone when opened from it): one ruler for the setting picked in a row of dials (Auto, Exposure, Contrast,
/// Warmth, Tint, Saturation, Vibrance, Highlights, Shadows, Sharpness), each showing its value; a dial that is off
/// zero is yellow; for a clip a dial shows the take's value until the clip sets its own, and Reset
/// gives the clip the take's values again. The Auto dial is the measured correction (a step before the
/// dials, which stay as they are on top of it): its ruler is how much of it shows. Auto, Compare and the
/// picked setting's name, value and Reset share one line, so the controls fit the panel without
/// scrolling on an ordinary iPhone. Reset puts them all back, and the setting on the ruler has its own.
struct AdjustPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    /// What the ruler is for: the measured correction's intensity, or one dial.
    private enum Pick: Hashable {
        case auto
        case dial(QuickEditViewModel.Adjustment)
    }

    @State private var current: Pick = .dial(.exposure)

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .adjust, onReset: reset) {
            dials
            readout
            ruler
        }
    }

    @ViewBuilder private var ruler: some View {
        switch current {
        case .auto:
            if viewModel.hasAuto {
                PanelRulerSlider(
                    label: String(localized: "Auto"), value: viewModel.autoAmount * 100, range: 0...100, bipolar: false,
                    format: .percent, identifier: "edit.adjust.autoAmount",
                    onChange: { viewModel.setAutoAmount($0) }
                )
            } else {
                PanelNote(text: String(localized: "Auto measures the picture and corrects its light and color. Your own adjustments stay on top."))
            }
        case .dial(let adjustment):
            PanelRulerSlider(
                label: adjustment.label, value: viewModel.adjustment(adjustment), range: range(of: adjustment), bipolar: adjustment.isBipolar,
                format: format(of: adjustment), identifier: "edit.adjust.ruler",
                onChange: { viewModel.setAdjustment(adjustment, $0) }
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
                autoDial
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

    private func dialLabel(_ title: String, picked isPicked: Bool, changed isChanged: Bool, @ViewBuilder content: () -> some View) -> some View {
        let ring: Color = isPicked ? Palette.ink : isChanged ? Palette.acc : Palette.adjustDialRing
        return VStack(spacing: 6) {
            content()
                .frame(width: 48, height: 48)
                .background(isPicked ? Palette.ink : Color.clear, in: Circle())
                .overlay(Circle().strokeBorder(ring, lineWidth: 2))
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(isPicked ? Palette.ink : Palette.ink2)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(minWidth: 64, minHeight: Metrics.hitTarget)
        .contentShape(Rectangle())
    }

    /// The measured correction: its intensity once there is one, a spark before.
    private var autoDial: some View {
        let isPicked = current == .auto
        let hasAuto = viewModel.hasAuto
        let ink: Color = isPicked ? Palette.bg : hasAuto ? Palette.accText : Palette.ink
        let text = PanelValueFormat.plain.text(viewModel.autoAmount * 100)
        return Button {
            current = .auto
        } label: {
            dialLabel(String(localized: "Auto"), picked: isPicked, changed: hasAuto && viewModel.autoAmount > 0) {
                if viewModel.autoState == .analyzing {
                    ProgressView().tint(ink)
                } else if hasAuto {
                    Text(text).font(.system(size: 14, weight: .bold).monospacedDigit()).foregroundStyle(ink)
                } else {
                    Image(systemName: "sparkles").font(.system(size: 17, weight: .semibold)).foregroundStyle(ink)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Auto"))
        .accessibilityValue(hasAuto ? Text(PanelValueFormat.percent.text(viewModel.autoAmount * 100)) : Text("Not measured"))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
        .accessibilityIdentifier("edit.adjust.autoDial")
    }

    private func dial(_ adjustment: QuickEditViewModel.Adjustment) -> some View {
        let isPicked = current == .dial(adjustment)
        let value = viewModel.adjustment(adjustment)
        let isChanged = value != 0
        let ink: Color = isPicked ? Palette.bg : isChanged ? Palette.accText : Palette.ink
        return Button {
            current = .dial(adjustment)
        } label: {
            dialLabel(adjustment.label, picked: isPicked, changed: isChanged) {
                Text(format(of: adjustment).text(value))
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(ink)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(adjustment.label))
        .accessibilityValue(Text(format(of: adjustment).text(value)))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
        .accessibilityIdentifier("edit.adjust.\(adjustment.rawValue)")
    }

    /// "Exposure  +10" with its own Reset once it is off zero; Compare and Auto at the other end.
    private var readout: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(currentLabel).font(.system(.subheadline, weight: .semibold))
                Text(currentValueText)
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
            if canResetCurrent {
                Button("Reset") { resetCurrent() }
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .buttonStyle(.plain)
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
                    .accessibilityLabel(Text("Reset"))
                    .accessibilityValue(Text(currentLabel))
                    .accessibilityIdentifier("edit.adjust.resetOne")
            }
            Spacer(minLength: 0)
            compareButton
            autoButton
        }
        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
    }

    private var currentLabel: String {
        switch current {
        case .auto: String(localized: "Auto")
        case .dial(let adjustment): adjustment.label
        }
    }

    private var currentValueText: String {
        switch current {
        case .auto: viewModel.hasAuto ? PanelValueFormat.percent.text(viewModel.autoAmount * 100) : ""
        case .dial(let adjustment): format(of: adjustment).text(viewModel.adjustment(adjustment))
        }
    }

    private var canResetCurrent: Bool {
        switch current {
        case .auto: viewModel.canResetAuto
        case .dial(let adjustment): viewModel.canResetAdjustment(adjustment)
        }
    }

    private func resetCurrent() {
        switch current {
        case .auto: viewModel.resetAuto()
        case .dial(let adjustment): viewModel.resetAdjustment(adjustment)
        }
    }

    /// For a clip, where the dial's value comes from while the clip hasn't set it.
    private var inheritedNote: String? {
        guard viewModel.lookClip != nil else { return nil }
        switch current {
        case .auto: return viewModel.clipOverridesAuto || !viewModel.hasAuto ? nil : String(localized: "From the whole take")
        case .dial(let adjustment): return viewModel.clipOverrides(adjustment) ? nil : String(localized: "From the whole take")
        }
    }

    /// Hold the original against the edit: tap to show the picture as recorded, tap again to come back.
    private var compareButton: some View {
        let isOn = viewModel.comparesPicture
        return Button(action: viewModel.togglePictureComparison) {
            Image(systemName: isOn ? "eye.fill" : "eye")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOn ? Palette.accInk : Palette.ink)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .background(isOn ? Palette.acc : Palette.fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(viewModel.edit.hasPictureLook || isOn ? 1 : 0.4)
        .accessibilityLabel(Text("Compare with original"))
        .accessibilityValue(isOn ? Text("Showing the original") : Text("Showing your edit"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("edit.adjust.compare")
    }

    /// Measures the picture (the take's, or the picked clip's) and applies a correction.
    private var autoButton: some View {
        let isWorking = viewModel.autoState == .analyzing
        return Button {
            current = .auto
            viewModel.autoAdjust()
        } label: {
            Label(isWorking ? String(localized: "Measuring…") : String(localized: "Auto"), systemImage: "sparkles")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: Metrics.hitTarget)
                .background(Palette.fill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .accessibilityIdentifier("edit.adjust.auto")
    }
}
