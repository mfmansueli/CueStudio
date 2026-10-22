//
//  WatchScreenRule.swift
//  Cue Studio
//

import Foundation

/// The watch's screen from what it knows: the iPhone's last state, whether the iPhone can be reached and the command still
/// waiting for its answer. Pure, so every state of the v31 board is tested without a watch.
nonisolated enum WatchScreenRule {
    /// A command whose effect the iPhone hasn't shown in this long is "No response" (the iPhone may still have done it).
    static let answerTimeout: TimeInterval = 5

    static func screen(
        state: WatchPhoneState?, isReachable: Bool, pending: WatchCommand?, pendingSince: Date?, now: Date, leftSavedTake: Bool
    ) -> WatchScreen {
        guard isReachable else { return state == nil ? .checking : .lost }
        guard let state else { return .checking }
        // A command still waiting shows that it waits, until the iPhone names it as answered; one the iPhone already shows
        // working (a take saving after End) shows that instead.
        if let pending, state.answering != pending.id, let waiting = waiting(for: pending.action, in: state.phase) {
            if let pendingSince, now.timeIntervalSince(pendingSince) > answerTimeout { return .noResponse }
            return waiting
        }
        switch state.phase {
        case .noSession: return .noSession
        case .unavailable: return .unavailable
        case .ready: return .ready
        case .countdown(let remaining): return .countdown(remaining: remaining)
        case .recording: return .recording
        case .saving: return .saving
        case .saved(let take, let seconds): return leftSavedTake ? .ready : .saved(take: take, seconds: seconds)
        case .rehearsal: return .rehearsal
        case .failedStart: return .failedStart
        case .failedSave: return .failedSave
        }
    }

    /// What a command shows while its answer is on the way; nil when the screen stays as it is (reading, speed).
    private static func waiting(for action: WatchAction, in phase: WatchPhase) -> WatchScreen? {
        switch (action, phase) {
        case (.record, .ready), (.record, .saved), (.record, .failedStart), (.record, .failedSave), (.record, .rehearsal): .requesting
        case (.stop, .recording): .stopping
        case (.rehearse, .ready), (.endRehearsal, .rehearsal): .sending
        case (.refresh, .noSession), (.refresh, .unavailable): .checking
        default: nil
        }
    }

    /// "00:42": a take's time, minutes and seconds.
    static func clock(_ seconds: Double) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }
}
