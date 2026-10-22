//
//  WatchRecordingPage.swift
//  Cue Studio Watch
//

import SwiftUI

/// Recording: the take's time, counted on the wrist from when the iPhone started it, and End, which asks twice (the second
/// tap within 3 s) so a brush of the sleeve never ends a take.
struct WatchRecordingPage: View {
    let session: WatchSessionModel

    var body: some View {
        VStack(spacing: 0) {
            Text("Recording")
                .font(.headline)
                .foregroundStyle(WatchPalette.recordText)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(WatchScreenRule.clock(elapsed(at: context.date)))
                    .font(.system(size: 40, weight: .semibold).monospacedDigit())
                    .foregroundStyle(WatchPalette.ink)
            }
            Text(session.state?.scriptTitle ?? String(localized: "Freestyle recording"))
                .font(.caption2)
                .foregroundStyle(WatchPalette.inkSoft)
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        Button(action: session.tapEnd) {
            if session.isArmed {
                Text("Tap again to end")
            } else {
                Label("End", systemImage: "stop.fill")
            }
        }
        .buttonStyle(WatchButtonStyle(kind: .stop(armed: session.isArmed)))
        .accessibilityHint(session.isArmed ? Text("Ends the take on your iPhone") : Text("Tap twice to end the take"))
    }

    private func elapsed(at date: Date) -> Double {
        session.state?.recordingStartedAt.map { date.timeIntervalSince($0) } ?? 0
    }
}
