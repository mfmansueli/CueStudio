//
//  WatchNotice.swift
//  Cue Studio Watch
//

import SwiftUI

/// What a screen without the recorder says: its symbol and color, title, what to do, and the one button (v31 board).
struct WatchNotice {
    let symbol: String
    let tone: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    /// The button and what it asks; nil without one.
    let button: (title: LocalizedStringKey, action: WatchAction)?
    /// "iPhone connected" under Prepare on your iPhone.
    let showsLink: Bool

    init(screen: WatchScreen) {
        switch screen {
        case .noSession:
            self.init("iphone", WatchPalette.reading, "Prepare on your iPhone", "Open Cue on your iPhone and pick a script or a freestyle recording.", nil, link: true)
        case .lost:
            self.init("iphone.slash", WatchPalette.warning, "No connection", "Recording may go on on your iPhone. Check there.", ("Try again", .refresh))
        case .noResponse:
            self.init("iphone", WatchPalette.warning, "No response", "Check on your iPhone that it was done.", ("Refresh", .refresh))
        case .failedStart:
            self.init("exclamationmark.triangle", WatchPalette.warning, "Didn't start recording", "Check the camera on your iPhone.", ("Try again", .record))
        case .failedSave:
            self.init("exclamationmark.triangle", WatchPalette.warning, "Save not confirmed", "Check on your iPhone that the take was saved.", ("OK", .done))
        default:
            self.init("clock", WatchPalette.inkMuted, "Unavailable now", "Go back to the recording screen on your iPhone.", ("OK", .refresh))
        }
    }

    private init(
        _ symbol: String, _ tone: Color, _ title: LocalizedStringKey, _ detail: LocalizedStringKey,
        _ button: (title: LocalizedStringKey, action: WatchAction)?, link: Bool = false
    ) {
        self.symbol = symbol
        self.tone = tone
        self.title = title
        self.detail = detail
        self.button = button
        showsLink = link
    }

    /// "Last state at 9:41: recording, 00:42".
    static func staleLine(for state: WatchPhoneState) -> String {
        let time = state.sentAt.formatted(date: .omitted, time: .shortened)
        return String(localized: "Last state at \(time): \(phaseLine(for: state))")
    }

    private static func phaseLine(for state: WatchPhoneState) -> String {
        switch state.phase {
        case .recording:
            let seconds = state.recordingStartedAt.map { state.sentAt.timeIntervalSince($0) } ?? 0
            return String(localized: "recording, \(WatchScreenRule.clock(seconds))")
        case .countdown: return String(localized: "counting down")
        case .saving: return String(localized: "saving")
        case .saved(let take, _): return String(localized: "take \(take) saved")
        case .rehearsal: return String(localized: "rehearsing")
        case .ready: return String(localized: "ready")
        case .noSession, .unavailable, .failedStart, .failedSave: return String(localized: "not recording")
        }
    }
}
