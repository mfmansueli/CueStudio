//
//  StopWarningCard.swift
//  Cue Studio
//

import SwiftUI

/// Shown when stopping before the take reaches the monetization minimum.
struct StopWarningCard: View {
    let title: String
    let message: String
    let onStop: () -> Void
    let onKeepGoing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "stopwatch")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.warnText)
                    .frame(width: 36, height: 36)
                    .background(Palette.warn.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline.monospacedDigit())
                    Text(message).font(.subheadline).foregroundStyle(Palette.ink2)
                }
            }
            HStack(spacing: 8) {
                Button("Stop anyway", action: onStop)
                    .buttonStyle(.cueSecondary())
                    .accessibilityIdentifier("prompter.stopAnywayButton")
                Button("Keep going", action: onKeepGoing)
                    .buttonStyle(.cuePrimary())
                    .accessibilityIdentifier("prompter.keepGoingButton")
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 25, y: 20)
    }
}

#if DEBUG
#Preview {
    StopWarningCard(
        title: "18s short of 1:00",
        message: "TikTok only pays Creator Rewards on videos longer than one minute.",
        onStop: {}, onKeepGoing: {}
    )
    .padding()
    .background(CameraFeedPlaceholder())
}
#endif
