//
//  TopicBirthOverlay.swift
//  Cue Studio
//

import SwiftUI

/// The births of the topics picked in the last few seconds, drawn over the whole chapter (the light travels from the chip to the orbit,
/// across everything between). Under Reduce Motion nothing is drawn: the world is simply there.
struct TopicBirthOverlay: View {
    let births: [TopicBirth]
    /// UI tests: the birth stands still at this age.
    var frozenAge: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || births.isEmpty || frozenAge != nil)) { context in
            Canvas { canvas, _ in
                for birth in births {
                    let age = frozenAge ?? context.date.timeIntervalSince(birth.tap)
                    guard age >= 0, age < TopicBirth.duration else { continue }
                    TopicBirthPainter(birth: birth, age: age).paint(in: &canvas)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
