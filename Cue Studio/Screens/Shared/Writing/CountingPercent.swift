//
//  CountingPercent.swift
//  Cue Studio
//

import SwiftUI

/// "42%" that counts: animated from one value to the next, it runs through every whole number between them instead of jumping, the way
/// a counter turns. The digits keep their width, so the number never shifts as it counts; the sign is dimmer than the digits (`Palette.ink2`).
/// Rounded down, as `WritingProgressLabel`: 99.6% is not yet 100%. The caller sets the font, the digits' colour and the animation.
struct CountingPercent: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Self.styled(value))
            .monospacedDigit()
    }

    /// The number with its percent sign dimmed, wherever the language puts it ("42 %", "%42").
    static func styled(_ value: Double) -> AttributedString {
        var text = value.formatted(WritingProgressLabel.format.attributed)
        for (symbol, range) in text.runs[\.numberSymbol] where symbol == .percent {
            text[range].foregroundColor = Palette.ink2
        }
        return text
    }
}

#if DEBUG
#Preview {
    CountingPercent(value: 0.42)
        .hudFont()
        .foregroundStyle(Palette.Scripts.transitionInk)
        .padding()
        .background(Palette.Scripts.transitionCover)
}
#endif
