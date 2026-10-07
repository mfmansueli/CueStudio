//
//  StudioAdjustBar.swift
//  Cue Studio
//

import SwiftUI

/// The quick adjustments of Studio's bar: **Size · Line · Margin · Mirror · Aa**, as the system's glass buttons. Tapping a chip opens its
/// slider (the system's) right under the row (one at a time; tapping again closes it), so the bar stays small while the creator sets how
/// the text sits for their eyes.
/// Mirror flips the text for a beam-splitter glass, and Aa opens Display for the font, colors and background.
struct StudioAdjustBar: View {
    let onMore: () -> Void

    @Environment(SessionSetupService.self) private var session
    @State private var selected: StudioAdjustment?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(StudioAdjustment.allCases) { adjustment in
                    chip(adjustment)
                }
                mirrorChip
                moreChip
            }
            if let selected {
                slider(for: selected)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.22), value: selected)
    }

    // MARK: - Chips

    private func chip(_ adjustment: StudioAdjustment) -> some View {
        chipButton(isOn: selected == adjustment) {
            selected = selected == adjustment ? nil : adjustment
        } label: {
            VStack(spacing: 3) {
                CueIconView(adjustment.icon, size: 20)
                Text(adjustment.title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .accessibilityLabel(Text(adjustment.spokenName))
        .accessibilityAddTraits(selected == adjustment ? .isSelected : [])
        .accessibilityIdentifier("studio.adjust.\(adjustment.rawValue)")
    }

    private var mirrorChip: some View {
        let isOn = session.prompter.isMirrored
        return chipButton(isOn: isOn) {
            session.prompter.isMirrored.toggle()
        } label: {
            VStack(spacing: 3) {
                CueIconView(.mirrorText, size: 20)
                Text("Mirror").font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .accessibilityLabel(Text("Mirror text"))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
        .accessibilityIdentifier("studio.adjust.mirror")
    }

    private var moreChip: some View {
        chipButton(isOn: false, action: onMore) {
            VStack(spacing: 3) {
                Text("Aa").font(.system(size: 17, weight: .semibold)).frame(height: 20)
                Text("More").font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .accessibilityLabel(Text("Display settings"))
        .accessibilityIdentifier("prompter.displayButton")
    }

    /// One chip: the system's Liquid Glass button, prominent and white when on (a chip is never yellow: yellow is the screen's action).
    @ViewBuilder
    private func chipButton(isOn: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        let content = label()
            .foregroundStyle(isOn ? Palette.chipOnInk : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 40)
        Group {
            if isOn {
                Button(action: action) { content }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.chipOn)
            } else {
                Button(action: action) { content }
                    .buttonStyle(.glass)
            }
        }
        .buttonBorderShape(.roundedRectangle(radius: 16))
    }

    // MARK: - Sliders

    @ViewBuilder
    private func slider(for adjustment: StudioAdjustment) -> some View {
        switch adjustment {
        case .size: sizeSlider
        case .line: lineSlider
        case .margin: marginSlider
        }
    }

    /// Small · Medium · Large · Extra large, as in Settings (Studio reads them 1.35× bigger).
    private var sizeSlider: some View {
        let sizes = PrompterTextSize.allCases
        let current = sizes.indices.min { abs(sizes[$0].points - session.prompter.size) < abs(sizes[$1].points - session.prompter.size) } ?? 2
        let spec = CueSliderSpec.textSize
        return LabeledSlider(
            label: String(localized: "Size"), valueText: sizes[current].label,
            value: Binding(
                get: { Double(current) },
                set: { session.prompter.size = sizes[max(0, min(sizes.count - 1, Int($0.rounded())))].points }
            ),
            range: spec.range, step: spec.step,
            accessibilityIdentifier: "studio.slider.size"
        )
    }

    /// Where the reading line crosses the screen, from the top: 10% to 60%.
    private var lineSlider: some View {
        let range = PrompterSettings.guideRange
        return LabeledSlider(
            label: String(localized: "Line"),
            valueText: (session.prompter.guidePosition).formatted(.percent.precision(.fractionLength(0)).locale(.interface)),
            value: Binding(
                get: { (session.prompter.guidePosition * 100).rounded() },
                set: { session.prompter.guidePosition = min(range.upperBound, max(range.lowerBound, $0 / 100)) }
            ),
            range: (range.lowerBound * 100)...(range.upperBound * 100), step: 1,
            accessibilityIdentifier: "studio.slider.line"
        )
    }

    private var marginSlider: some View {
        let spec = CueSliderSpec.margins
        return LabeledSlider(
            label: String(localized: "Margin"), valueText: String(localized: "\(Int(session.prompter.margin)) pt"),
            value: Binding(
                get: { session.prompter.margin },
                set: { session.prompter.margin = min(PrompterSettings.marginRange.upperBound, max(PrompterSettings.marginRange.lowerBound, $0)) }
            ),
            range: spec.range, step: spec.step,
            accessibilityIdentifier: "studio.slider.margin"
        )
    }
}
