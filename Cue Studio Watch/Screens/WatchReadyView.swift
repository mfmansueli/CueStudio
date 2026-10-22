//
//  WatchReadyView.swift
//  Cue Studio Watch
//

import SwiftUI

/// Ready: the script (or freestyle), how it scrolls, Record in its place, and Rehearse under it when there is a script.
struct WatchReadyView: View {
    let session: WatchSessionModel

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 2) {
            if let title = state?.scriptTitle {
                Text("SCRIPT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WatchPalette.inkSoft)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(WatchPalette.ink)
                    .lineLimit(3)
                WatchScrollModeLabel(followsVoice: state?.followsVoice ?? false, speedMultiple: state?.speedMultiple ?? 1)
                    .padding(.top, 2)
            } else {
                Text("Freestyle recording")
                    .font(.headline)
                    .foregroundStyle(WatchPalette.ink)
                Text("No script on screen")
                    .font(.caption2)
                    .foregroundStyle(WatchPalette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        Button { session.send(.record) } label: {
            Label("Record", systemImage: "record.circle")
        }
        .buttonStyle(WatchButtonStyle(kind: .record))
        if state?.scriptTitle != nil {
            Button("Rehearse") { session.send(.rehearse) }
                .buttonStyle(WatchButtonStyle())
        }
    }
}
