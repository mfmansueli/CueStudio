//
//  WatchRootView.swift
//  Cue Studio Watch
//

import SwiftUI

/// One screen at a time, the one `WatchScreenRule` says, under the status at the top (the system shows the time beside it).
struct WatchRootView: View {
    let session: WatchSessionModel

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { WatchStatusLabel(screen: session.screen, state: session.state) }
                }
                .background(WatchPalette.background)
        }
    }

    @ViewBuilder private var content: some View {
        switch session.screen {
        case .recording:
            WatchTakeView(session: session)
        default:
            ScrollView {
                VStack(spacing: 8) { screen }
                    .padding(.horizontal, 4)
            }
        }
    }

    @ViewBuilder private var screen: some View {
        switch session.screen {
        case .checking:
            WatchWaitView(title: "Checking your iPhone", detail: "The state appears when your iPhone answers.")
        case .requesting:
            WatchWaitView(title: "Asking your iPhone", detail: "It isn't recording yet.") { session.send(.cancelCountdown) }
        case .stopping:
            WatchWaitView(title: "Ending on your iPhone", detail: "Wait for the confirmation.")
        case .saving:
            WatchWaitView(title: "Saving on your iPhone", detail: "Wait for the confirmation.")
        case .sending:
            WatchWaitView(title: "Sending to your iPhone", detail: "Wait for the confirmation.")
        case .ready:
            WatchReadyView(session: session)
        case .countdown(let remaining):
            WatchCountdownView(remaining: remaining) { session.send(.cancelCountdown) }
        case .saved(let take, let seconds):
            WatchSavedView(take: take, seconds: seconds, session: session)
        case .rehearsal:
            WatchTextControls(session: session, isRecording: false)
        case .noSession, .lost, .noResponse, .failedStart, .failedSave, .unavailable:
            WatchNoticeView(notice: WatchNotice(screen: session.screen), stale: staleLine) { action in session.send(action) }
        case .recording:
            EmptyView()
        }
    }

    /// No connection: the last thing the iPhone said, marked as old.
    private var staleLine: String? {
        guard session.screen == .lost, let state = session.state else { return nil }
        return WatchNotice.staleLine(for: state)
    }
}
