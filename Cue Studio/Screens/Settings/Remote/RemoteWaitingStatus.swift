//
//  RemoteWaitingStatus.swift
//  Cue Studio
//

import SwiftUI

/// "Waiting for your other device…" under the code, in the prompter's yellow, its three dots lighting one after another like a breath.
/// Reduce Motion: the dots stay lit.
struct RemoteWaitingStatus: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds for the three dots to light in turn.
    private static let period: TimeInterval = 1.4

    var body: some View {
        let words = text.replacingOccurrences(of: "…", with: "").replacingOccurrences(of: "...", with: "")
        TimelineView(.animation(paused: reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.period
            HStack(spacing: 1) {
                Text(verbatim: words)
                ForEach(0..<3, id: \.self) { dot in
                    Text(verbatim: ".").opacity(reduceMotion ? 1 : Self.light(of: dot, at: phase))
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Palette.accText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
        .accessibilityIdentifier("remote.status")
    }

    /// A dot's brightness: up as its turn comes, back down after, never below a quarter.
    private static func light(of dot: Int, at phase: Double) -> Double {
        let center = 0.2 + Double(dot) * 0.2
        let distance = abs(phase - center)
        return 0.25 + 0.75 * max(0, 1 - distance / 0.2)
    }
}
