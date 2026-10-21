//
//  ArrivingLines.swift
//  Cue Studio
//

import SwiftUI

/// A long text arriving a line at a time, each line its own `ArrivingText` (as one, a script past 1:30 grew too tall to draw with its blur
/// and glow and the whole text vanished: the owner saw it, 20/10/2026). One clock for every line, so the words keep arriving in order down
/// the page (a line never starts before the one above has finished) and the caret is on the line whose words are arriving.
struct ArrivingLines: View {
    let lines: [AttributedString]
    var size: CGFloat = 19
    var lineSpacing: CGFloat = 6

    @State private var clock = ArrivalClock()

    var body: some View {
        // Slots are given when the text grows (this body runs then), at the moment the words come in, as `ArrivingText` gives its own.
        let counts = lines.map { ArrivingText.tokens(of: $0).count }
        let times = clock.arrivals(for: counts.reduce(0, +), now: Date.now.timeIntervalSinceReferenceDate)
        let schedules = ArrivalSchedule.split(times, counts: counts)
        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                ArrivingText(styled: line, size: size, lineSpacing: lineSpacing, schedule: schedules[index])
            }
        }
        // One element, as the text it will be: VoiceOver reads it whole, and its frame is the words' (a blank line alone isn't one).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(lines.map { String($0.characters) }.joined(separator: "\n")))
    }
}
