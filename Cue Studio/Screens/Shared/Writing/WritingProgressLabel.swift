//
//  WritingProgressLabel.swift
//  Cue Studio
//

import SwiftUI

/// "42%": how much of a script Apple Intelligence has written (`WritingProgressMeter`), under the star and in the page's pill. It moves with
/// the words as they arrive, and by itself while the model reads the request; the digits roll, except under Reduce Motion. It is never 100%
/// before the script is there. The caller sets the font and the colour.
struct WritingProgressLabel: View {
    let meter: WritingProgressMeter

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Rounded down: 99.6% is not yet 100%.
    static let format = FloatingPointFormatStyle<Double>.Percent.percent.precision(.fractionLength(0)).rounded(rule: .down)

    var body: some View {
        // A few looks a second: the words arriving update it as they come; the clock only matters while the model reads.
        TimelineView(.animation(minimumInterval: 0.25, paused: meter.isFinished)) { _ in
            let fraction = meter.fraction
            Text(fraction, format: Self.format)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText(value: fraction))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: Int(fraction * 100))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Written so far"))
        .accessibilityValue(Text(meter.fraction, format: Self.format))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#if DEBUG
#Preview {
    let meter = WritingProgressMeter(expectedWords: 150)
    meter.record(.drafting)
    meter.record(.wrote(words: 64))
    return WritingProgressLabel(meter: meter)
        .font(CueStudioFont.hud)
        .foregroundStyle(Palette.ink2)
        .padding()
        .background(Palette.Scripts.transitionCover)
}
#endif
