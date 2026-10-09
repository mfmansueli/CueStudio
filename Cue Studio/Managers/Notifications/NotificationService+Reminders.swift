//
//  NotificationService+Reminders.swift
//  Cue Studio
//

import Foundation

/// The reminders the creator sets (a script, a take, Post later) and their routine. They ring at the time chosen, outside the caps and the
/// quiet hours; the system's yes is what makes one "set". Kept in Cue whatever iOS allows, so nothing is lost while notifications are off.
extension NotificationService {
    /// Reminders still ahead, nearest first, then the due ones (kept a week).
    var upcomingReminders: [Reminder] {
        let moment = now()
        let calendar = calendar()
        return state.reminders.sorted { lhs, rhs in
            let (left, right) = (lhs.isDue(at: moment, calendar: calendar), rhs.isDue(at: moment, calendar: calendar))
            return left == right ? lhs.time < rhs.time : !left
        }
    }

    func reminders(about subject: ReminderSubject) -> [Reminder] {
        state.reminders.filter { $0.subject == subject }
    }

    /// Sets a reminder (or changes `replacing`). Asks iOS the first time. Only `scheduled` means the system will deliver it.
    func setReminder(_ subject: ReminderSubject, title: String, at time: LocalDateTime, replacing id: UUID? = nil) async -> ReminderResult {
        let calendar = calendar()
        let moment = now()
        guard !ReminderChoice.isPast(time, now: moment, calendar: calendar), let date = time.date(in: calendar) else { return .past }
        // Setting one is the creator's own yes to reminders, even after turning the category off.
        if !isOn(.reminders) { mutate { $0.consent[NotificationCategory.reminders.rawValue] = true } }
        let allowed = await requestAuthorizationIfNeeded()
        var reminder = Reminder(id: id ?? UUID(), subject: subject, time: time, createdAt: moment, title: title)
        guard allowed.canSchedule else {
            keep(reminder)
            setNeedsReconcile()
            return .savedNotificationsOff
        }
        let ahead = state.reminders.filter { $0.id != reminder.id && !$0.isDue(at: moment, calendar: calendar) && $0.time < time }
        guard ahead.count < policy.reminderCapacity else {
            keep(reminder)
            setNeedsReconcile()
            return .savedWaiting
        }
        let request = request(for: reminder, calendar: calendar)
        do {
            try await center.add(request)
        } catch {
            measure(.schedulingFailed, campaign: request.payload.campaignName, category: .reminders)
            return .failed
        }
        reminder.isScheduled = true
        keep(reminder)
        mutate { $0.scheduledSignatures[request.identifier] = Self.signature(of: request) }
        measure(.scheduled, campaign: request.payload.campaignName, category: .reminders)
        // The automatic ones move away from it (12 hours), and a reminder pushed past the places waits.
        setNeedsReconcile()
        return .scheduled(date)
    }

    func cancelReminder(_ id: UUID) {
        guard let reminder = state.reminders.first(where: { $0.id == id }) else { return }
        center.removePending([reminder.requestID])
        center.removeDelivered([reminder.requestID])
        mutate { state in
            state.reminders.removeAll { $0.id == id }
            state.scheduledSignatures[reminder.requestID] = nil
        }
        measure(.cancelled, campaign: "reminders.reminder", category: .reminders)
        setNeedsReconcile()
    }

    private func keep(_ reminder: Reminder) {
        mutate { state in
            state.reminders.removeAll { $0.id == reminder.id }
            state.reminders.append(reminder)
        }
    }

    // MARK: - Routine

    /// Saves the routine (nil removes it) and turns the category on with it; asks iOS the first time.
    @discardableResult
    func setRoutine(_ routine: CreationRoutine?) async -> NotificationAuthorization {
        mutate { state in
            state.routine = routine
            if routine != nil { state.consent[NotificationCategory.routine.rawValue] = true }
        }
        let allowed = routine == nil ? authorization : await requestAuthorizationIfNeeded()
        await reconcile()
        return allowed
    }

    /// A time the creator chose falls in their quiet hours (it rings anyway; the screen says so).
    func isInQuietHours(_ time: LocalDateTime) -> Bool { state.quietHours.contains(time) }
}
