//
//  WatchSavedView.swift
//  Cue Studio Watch
//

import SwiftUI

/// The take is in the iPhone's library: its number and length, Record another, Done.
struct WatchSavedView: View {
    let take: Int
    let seconds: Double
    let session: WatchSessionModel

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(WatchPalette.onSaved)
                .frame(width: 40, height: 40)
                .background(WatchPalette.saved, in: Circle())
                .accessibilityHidden(true)
            Text("Take saved")
                .font(.headline)
                .foregroundStyle(WatchPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Take \(take) · \(WatchScreenRule.clock(seconds))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(WatchPalette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        Button("Record another") { session.send(.record) }
            .buttonStyle(WatchButtonStyle(kind: .record))
        Button("Done") { session.send(.done) }
            .buttonStyle(WatchButtonStyle())
    }
}
