//
//  StudioAdjustSlider.swift
//  Cue Studio
//

import SwiftUI

/// The slider of the quick adjustment chosen in Studio's bar (`StudioAdjustBar`): Size, Line or Margin, the system's slider with its name and
/// value above it. It takes the place of the speed slider while an adjustment is chosen (`StudioControlPanel`), so choosing one changes nothing
/// of the bar's size.
struct StudioAdjustSlider: View {
    let adjustment: StudioAdjustment

    @Environment(SessionSetupService.self) private var session

    var body: some View {
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
