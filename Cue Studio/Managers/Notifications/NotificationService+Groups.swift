//
//  NotificationService+Groups.swift
//  Cue Studio
//

import Foundation

/// The three switches of Settings › Notifications (`NotificationGroup`) and its "Turn on": a yes from iOS there turns on everything Cue
/// sends, since the card said what (reminders, the routine, tools and news).
extension NotificationService {
    func isGroupOn(_ group: NotificationGroup) -> Bool {
        group.categories.contains { isOn($0) }
    }

    /// Sets every category of `group`; the routine, switched on without days yet, starts on its usual ones (Mon, Wed, Fri at 6 PM).
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

    /// "Turn on": asks iOS when it hasn't been asked, and with a yes turns everything on (`turnEverythingOn`). Returns what iOS answered, as
    /// soon as it answers: the page celebrates while the plan is made.
    @discardableResult
    func allowEverything() async -> NotificationAuthorization {
        let answer = await requestAuthorizationIfNeeded()
        if answer.canSchedule { turnEverythingOn() }
        return answer
    }

    /// Every category on, and the routine on its usual days if none was set; the plan is made again right after.
    func turnEverythingOn() {
        mutate { state in
            for category in NotificationCategory.allCases { state.consent[category.rawValue] = true }
            if state.routine == nil { state.routine = CreationRoutine() }
        }
        setNeedsReconcile()
    }
}
