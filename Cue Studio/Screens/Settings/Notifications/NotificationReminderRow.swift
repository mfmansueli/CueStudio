//
//  NotificationReminderRow.swift
//  Cue Studio
//

import SwiftUI

/// One reminder in Settings › Notifications: what it is about, when, and whether iOS holds it ("Due" once its time passed, "Kept in Cue"
/// while notifications are off or it waits for a place).
struct NotificationReminderRow: View {
    let reminder: Reminder

    private var calendar: Calendar { .current }

    private var kind: String {
        switch reminder.subject {
        case .script: String(localized: "Script")
        case .take: String(localized: "Take")
        case .share(_, let network): String(localized: "Post on \(network.platform.label)")
        }
    }

    private var status: String {
        if reminder.isDue(at: .now, calendar: calendar) { return String(localized: "Due") }
        return reminder.isScheduled ? String(localized: "Set") : String(localized: "Kept in Cue")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title.isEmpty ? kind : reminder.title)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(verbatim: "\(kind) · \(reminder.time.date(in: calendar).map { ReminderFeedback.when($0) } ?? "")")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 8)
            Text(status)
                .font(.footnote)
                .foregroundStyle(reminder.isScheduled ? Palette.ink2 : Palette.warnText)
        }
        .frame(minHeight: Metrics.listRowContent)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("notifications.reminder")
    }
}
