//
//  LengthNudgeSheet.swift
//  Cue Studio
//

import SwiftUI

/// "A bit long for TikTok": asked once, when Record is tapped on a script past the platform's range. Make it shorter (Apple Intelligence, or
/// Ultra AI on a script it wrote, which the button says: it sends the script to Google), or record anyway.
struct LengthNudgeSheet: View {
    let platform: Platform
    let seconds: TimeInterval
    let idealUpper: TimeInterval
    let onRecordAnyway: () -> Void
    let offersShorter: Bool
    /// Ultra AI shortens it (a script it wrote): the button says so.
    var shorterByUltra = false
    let onShorter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HUDLine(values: ["~\(DurationText.clock(seconds))", "\(platform.label) ideal ≤ \(DurationText.clock(idealUpper))"])
            Text("A bit long for \(platform.label)")
                .cueFont(.title3, weight: .bold)
                .foregroundStyle(Palette.ink)
            Text("Make it shorter, or record as is. You can trim later.")
                .cueFont(.subheadline)
                .foregroundStyle(Palette.ink2)
            Button(action: onRecordAnyway) {
                HStack(spacing: 7) {
                    Circle().fill(Palette.record).frame(width: 9, height: 9)
                    Text("Record anyway")
                }
            }
            .buttonStyle(.cuePrimary())
            .accessibilityIdentifier("page.nudge.record")
            if offersShorter {
                Button(action: onShorter) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(shorterByUltra ? "Make it shorter with Ultra AI" : "Make it shorter")
                    }
                }
                .buttonStyle(.cueAI())
                .accessibilityIdentifier("page.nudge.shorter")
            }
        }
        .padding(EdgeInsets(top: 24, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
        .frame(maxWidth: .infinity, alignment: .leading)
        // A container, so its buttons keep their own identifiers.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.nudge")
    }
}
