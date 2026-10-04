//
//  LengthNudgeSheet.swift
//  Cue Studio
//

import SwiftUI

/// "A bit long for TikTok": asked once, when Record is tapped on a script past the platform's range. Make it shorter with Cue
/// (Apple Intelligence only), or record anyway.
struct LengthNudgeSheet: View {
    let platform: Platform
    let seconds: TimeInterval
    let idealUpper: TimeInterval
    let onRecordAnyway: () -> Void
    let offersShorter: Bool
    let onShorter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HUDLine(values: ["~\(DurationText.clock(seconds))", "\(platform.label) ideal ≤ \(DurationText.clock(idealUpper))"])
            Text("A bit long for \(platform.label)")
                .font(.title3.bold())
                .foregroundStyle(Palette.ink)
            Text("Make it shorter, or record as is — you can trim later.")
                .font(.subheadline)
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
                        Text("Make it shorter")
                    }
                }
                .buttonStyle(.cueAI())
                .accessibilityIdentifier("page.nudge.shorter")
            }
        }
        .padding(EdgeInsets(top: 24, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("page.nudge")
    }
}
