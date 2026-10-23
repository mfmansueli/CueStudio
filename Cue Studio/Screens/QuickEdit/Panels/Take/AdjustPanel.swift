//
//  AdjustPanel.swift
//  Cue Studio
//

import SwiftUI

/// Adjust (whole take, or the picked clip alone when opened from it): one ruler for the setting picked in a row
/// of chips (Auto, Exposure, Contrast, Warmth, Tint, Saturation, Vibrance, Highlights, Shadows, Sharpness, Skin
/// Smoothing: the faces' skin only, drawn before the other settings, see `FrameLook`): the
/// picked chip is white, one that is off zero shows its value in yellow; for a clip a chip shows the take's value
/// until the clip sets its own, and Reset gives the clip the take's values again. ◐ shows the picture as recorded
/// for as long as it is held. The Auto chip is the measured correction (a step before the other settings, which
/// stay as they are on top of it): its ruler is how much of it shows. Auto, ◐ and the picked setting's name, value
/// and Reset share one line (two or three on a narrow screen or with large text), so the controls fit the panel without
/// scrolling on an ordinary iPhone. Reset puts them all back, and the setting on the ruler has its own.
struct AdjustPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    /// What the ruler is for: the measured correction's intensity, or one dial.
    private enum Pick: Hashable {
        case auto
        case dial(QuickEditViewModel.Adjustment)
    }

    @State private var current: Pick = .dial(.exposure)
    /// A setting's name on its chip, growing with the text size.
    @ScaledMetric(relativeTo: .subheadline) private var chipTitleSize: CGFloat = 14

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .adjust, onReset: reset, compare: viewModel.pictureCompare) {
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
                PanelNote(text: String(localized: "Auto fixes light and color · Your edits stay on top"))
            }
        case .dial(let adjustment):
            PanelRulerSlider(
                label: adjustment.label, value: viewModel.adjustment(adjustment), range: range(of: adjustment), bipolar: adjustment.isBipolar,
                format: format(of: adjustment), identifier: "edit.adjust.ruler", hint: adjustment.hint,
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
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    autoChip
                    ForEach(QuickEditViewModel.Adjustment.allCases) { adjustment in
                        chip(adjustment).id(adjustment)
                    }
                }
            }
            .scrollIndicators(.hidden)
            // The row runs to the panel's edges, so a chip doesn't stop short of them when it scrolls.
            .padding(.horizontal, -16)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .onAppear {
                // Opened on one setting (a notification's "Try it" for Skin Smoothing): its chip is picked and in view; nothing changes.
                guard let start = viewModel.adjustOpensOn else { return }
                viewModel.adjustOpensOn = nil
                current = .dial(start)
                proxy.scrollTo(start, anchor: .trailing)
            }
        }
    }

    /// A setting as a chip: its name and, once it is off zero, its value in yellow. The picked one is
    /// white with black text, like every chosen chip.
    private func chipLabel(_ title: String, valueText: String?, picked isPicked: Bool, isMeasuring: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: chipTitleSize, weight: isPicked ? .semibold : .medium))
            if isMeasuring {
                ProgressView().controlSize(.mini).tint(isPicked ? Palette.chipOnInk : Palette.ink)
            } else if let valueText {
                Text(valueText)
                    .font(.system(.caption, weight: .bold).monospacedDigit())
                    .foregroundStyle(isPicked ? Palette.chipOnInk : Palette.accText)
            }
        }
        .foregroundStyle(isPicked ? Palette.chipOnInk : Palette.ink)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 13)
        .frame(height: 34)
        .background(isPicked ? Palette.chipOn : Palette.fill, in: Capsule())
        .frame(minHeight: Metrics.hitTarget)
        .contentShape(Rectangle())
    }

    /// The measured correction: its intensity once there is one.
    private var autoChip: some View {
        let isPicked = current == .auto
        let hasAuto = viewModel.hasAuto
        let text = PanelValueFormat.plain.text(viewModel.autoAmount * 100)
        return Button {
            current = .auto
        } label: {
            chipLabel(
                String(localized: "Auto"), valueText: hasAuto && viewModel.autoAmount > 0 ? text : nil,
                picked: isPicked, isMeasuring: viewModel.autoState == .analyzing
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Auto"))
        .accessibilityValue(hasAuto ? Text(PanelValueFormat.percent.text(viewModel.autoAmount * 100)) : Text("Not measured"))
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("edit.adjust.autoDial")
    }

    private func chip(_ adjustment: QuickEditViewModel.Adjustment) -> some View {
        let isPicked = current == .dial(adjustment)
        let value = viewModel.adjustment(adjustment)
        return Button {
            current = .dial(adjustment)
        } label: {
            chipLabel(adjustment.label, valueText: value != 0 ? format(of: adjustment).text(value) : nil, picked: isPicked)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(adjustment.label))
        .accessibilityValue(Text(format(of: adjustment).text(value)))
        .accessibilityHint(Text(adjustment.hint ?? ""))
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("edit.adjust.\(adjustment.rawValue)")
    }

    /// "Exposure  +10" with its own Reset once it is off zero; Auto at the other end (◐ is in the header). All on one line when it fits;
    /// otherwise the note goes under the name in the same line's height, and with large text the name, the note and the buttons
    /// each have a line of their own. A word never breaks and no label is cut.
    private var readout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                nameAndValue
                if let note = inheritedNote { noteText(note, lines: 1) }
                resetButton
                Spacer(minLength: 0)
                autoButton
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            // Narrower (a clip's "From the whole video" on an iPhone): the note under the name, in the same 44 pt line, so the
            // ruler stays where it was and shows whole.
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    nameAndValue
                    if let note = inheritedNote { noteText(note, lines: 1) }
                }
                resetButton
                Spacer(minLength: 0)
                autoButton
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            VStack(alignment: .leading, spacing: 4) {
                nameAndValue
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let note = inheritedNote { noteText(note, lines: 3) }
                HStack(alignment: .center, spacing: 10) {
                    resetButton
                    Spacer(minLength: 0)
                        autoButton
                }
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            }
        }
    }

    private var nameAndValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(currentLabel).font(.system(.subheadline, weight: .semibold))
            Text(currentValueText)
                .font(.system(.subheadline, weight: .bold).monospacedDigit())
                .foregroundStyle(Palette.accText)
        }
        .accessibilityElement(children: .combine)
    }

    private func noteText(_ note: String, lines: Int) -> some View {
        Text(note)
            .font(.system(.footnote))
            .foregroundStyle(Palette.ink2)
            .lineLimit(lines)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var resetButton: some View {
        if canResetCurrent {
            Button("Reset") { resetCurrent() }
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
                .fixedSize()
                .buttonStyle(.plain)
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
                .accessibilityLabel(Text("Reset"))
                .accessibilityValue(Text(currentLabel))
                .accessibilityIdentifier("edit.adjust.resetOne")
        }
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
        case .auto: return viewModel.clipOverridesAuto || !viewModel.hasAuto ? nil : String(localized: "From the whole video")
        case .dial(let adjustment): return viewModel.clipOverrides(adjustment) ? nil : String(localized: "From the whole video")
        }
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
                .lineLimit(1)
                .fixedSize()
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
