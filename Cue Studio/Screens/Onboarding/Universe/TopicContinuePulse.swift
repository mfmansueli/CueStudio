//
//  TopicContinuePulse.swift
//  Cue Studio
//

import SwiftUI

/// A ring of yellow light that opens round "Continue" once a topic's world has landed (1.6–2.9 s after the pick: 6 pt at 35%, then 16 pt at 0%).
struct TopicContinuePulse: View {
    /// When the last topic was picked.
    let since: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let since, !reduceMotion {
            TimelineView(.animation(paused: Date.now.timeIntervalSince(since) > TopicBirth.duration)) { context in
                let pose = TopicBirth.button.pose(at: context.date.timeIntervalSince(since))
                Capsule()
                    .strokeBorder(Palette.acc.opacity(pose.opacity), lineWidth: pose.scale)
                    .padding(-pose.scale)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}
