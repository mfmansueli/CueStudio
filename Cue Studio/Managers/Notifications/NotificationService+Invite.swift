//
//  NotificationService+Invite.swift
//  Cue Studio
//

import Foundation

/// The invitation to allow notifications, Cue's own before the system's (iOS asks once, so it is spent only on a yes). First right after
/// the creator has a recording to finish; once more, only after a "Not now" and 14 days later, when they leave a finished script without
/// recording it. Never on first launch or during the first flight, never while they record, edit, export or use the remote, never on a
/// day another introduction or a My Cue Voice tip was shown, and only while iOS hasn't been asked. Twice in the app's life at most.
extension NotificationService {
    static let inviteLimit = 2
    static let inviteGap: TimeInterval = 14 * 24 * 3600

    /// The invitation for this moment, or nil. `hasRecorded`: the creator has at least one take.
    func invite(_ reason: NotificationInviteReason, hasRecorded: Bool) async -> NotificationInviteReason? {
        guard invitesEnabled, !isForegroundBusy(), introsThisSession == 0 else { return nil }
        let moment = now()
        let calendar = calendar()
        guard state.invitesShown.count < Self.inviteLimit,
              state.invitesShown.last.map({ moment.timeIntervalSince($0) >= Self.inviteGap }) ?? true,
              !introducedToday, !tipDays().contains(where: { calendar.isDate($0, inSameDayAs: moment) }) else { return nil }
        switch reason {
        case .firstRecording: guard hasRecorded, state.invitesShown.isEmpty else { return nil }
        case .readyScript: guard state.invitesShown.count == 1 else { return nil }
        }
        await refreshAuthorization()
        guard authorization == .notDetermined else { return nil }
        return reason
    }

    func inviteShown(_ reason: NotificationInviteReason) {
        introsThisSession += 1
        mutate { $0.invitesShown.append(now()) }
        measure(.eligible, campaign: "invite.\(reason.rawValue)", category: .projects)
    }

    /// "Allow notifications": now the system asks. Returns what iOS answered.
    @discardableResult
    func inviteAccepted(_ reason: NotificationInviteReason) async -> NotificationAuthorization {
        measure(.featureStarted, campaign: "invite.\(reason.rawValue)", category: .projects)
        let answer = await requestAuthorizationIfNeeded()
        if answer.canSchedule { measure(.featureCompleted, campaign: "invite.\(reason.rawValue)", category: .projects) }
        await reconcile()
        return answer
    }

    /// "Not now": the system's question is kept for later.
    func inviteDeclined(_ reason: NotificationInviteReason) {
        measure(.snoozed, campaign: "invite.\(reason.rawValue)", category: .projects)
    }
}
