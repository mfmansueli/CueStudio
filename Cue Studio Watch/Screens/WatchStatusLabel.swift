//
//  WatchStatusLabel.swift
//  Cue Studio Watch
//

import SwiftUI

/// The top left of every screen: the link to the iPhone, REC during a take, GETTING READY in the countdown, REHEARSAL.
struct WatchStatusLabel: View {
    let screen: WatchScreen
    let state: WatchPhoneState?

    /// Room left for the system's time beside it, even on a 40 mm watch: a longer status shrinks instead of hiding the time.
    private static let widest: CGFloat = 84

    var body: some View {
        status
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: Self.widest, alignment: .leading)
    }

    @ViewBuilder private var status: some View {
        switch screen {
        case .ready, .requesting, .saved, .noSession, .failedStart, .failedSave, .unavailable, .saving:
            Label("iPhone", systemImage: "iphone")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WatchPalette.linked)
        case .lost, .noResponse, .checking:
            Label(linkTitle, systemImage: "iphone.slash")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WatchPalette.warning)
        case .recording, .stopping:
            Text("● REC")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(WatchPalette.record, in: Capsule())
                .foregroundStyle(WatchPalette.ink)
        case .countdown:
            Text("GETTING READY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(WatchPalette.reading)
        case .rehearsal, .sending:
            Text("REHEARSAL")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .overlay(Capsule().strokeBorder(WatchPalette.reading, lineWidth: 1))
                .foregroundStyle(WatchPalette.reading)
        }
    }

    private var linkTitle: LocalizedStringKey {
        switch screen {
        case .checking: "Connecting"
        case .lost: "No connection"
        default: "No response"
        }
    }
}
