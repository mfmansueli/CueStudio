//
//  NotificationService+Groups.swift
//  Cue Studio
//

import Foundation

/// The three switches of Settings › Notifications (`NotificationGroup`). A switch touched before iOS was asked asks it, and with a yes turns
/// on only that switch (owner, 30/10/2026): iOS allowing Cue is never a yes to anything else, and the routine is never switched on by itself.
extension NotificationService {
    /// On when one of its categories is; the routine only once it has its days and time.
    func isGroupOn(_ group: NotificationGroup) -> Bool {
        if group == .routine { return isOn(.routine) && state.routine != nil }
        return group.categories.contains { isOn($0) }
    }

    /// Sets every category of `group`; the routine, switched on without days yet, starts on the ones its switch showed (Mon, Wed, Fri at
    /// 6 PM), and its days and time open under it to change.
    func setGroup(_ group: NotificationGroup, isOn: Bool) async {
        if group == .routine, isOn, state.routine == nil {
            await setRoutine(CreationRoutine())
            return
        }
        mutate { state in
            for category in group.categories { state.consent[category.rawValue] = isOn }
        }
        if !isOn {
            for category in group.categories { measure(.optedOut, campaign: "category.\(category.rawValue)", category: category) }
        }
        await reconcile()
    }

    /// A switch touched while iOS was never asked: iOS asks, and with a yes only `group` turns on (nil: the switch on top, which is iOS's
    /// permission and nothing more). Returns what iOS answered, as soon as it answers: the page celebrates while the plan is made.
    @discardableResult
    func allow(turningOn group: NotificationGroup?) async -> NotificationAuthorization {
        let answer = await requestAuthorizationIfNeeded()
        guard answer.canSchedule else { return answer }
        if let group {
            await setGroup(group, isOn: true)
        } else {
            setNeedsReconcile()
        }
        return answer
    }
}
