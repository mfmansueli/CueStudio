//
//  ReminderSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Remind me": tonight, tomorrow, or a date and time the creator picks, for a script, a take or a network left for later. The reminders
/// already set for it are listed with a way to remove them. A time inside the quiet hours is allowed (the creator chose it) and the sheet says
/// so. The reminder opens the script, the take or the queue's step, never the camera, an export or a post.
struct ReminderSheet: View {
    let subject: ReminderSubject
    /// The project's title, for this sheet and the list in Settings (in a notification only with titles allowed in previews).
    let title: String
    /// Opens straight on the date and time ("Pick a date and time…" from Post later's menu).
    var startsPicking = false
    /// The reminder being changed (Settings › Notifications › a reminder).
    var editing: Reminder?
    /// After a reminder was set (or kept); the sheet has closed.
    var onSet: (ReminderResult) -> Void = { _ in }

    @Environment(NotificationService.self) private var notifications
    @Environment(\.dismiss) private var dismiss

    @State private var picksTime = false
    @State private var picked = Date.now.addingTimeInterval(3600)
    @State private var isSaving = false
    @State private var problem: String?

    private var calendar: Calendar { .current }

    private var tonight: LocalDateTime? { ReminderChoice.tonight.time(now: .now, calendar: calendar) }
    private var tomorrow: LocalDateTime? { ReminderChoice.tomorrow.time(now: .now, calendar: calendar) }
    private var pickedTime: LocalDateTime { LocalDateTime(picked, calendar: calendar) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(
                title: editing == nil ? String(localized: "Remind me") : String(localized: "Change reminder"),
                subtitle: title.isEmpty ? nil : title
            )
            GroupedCard {
                if !picksTime {
                    if let tonight { choice(String(localized: "Tonight"), tonight, id: "reminder.tonight") }
                    if let tomorrow { choice(String(localized: "Tomorrow"), tomorrow, id: "reminder.tomorrow") }
                }
                Button {
                    withAnimation(.smooth(duration: 0.2)) { picksTime.toggle() }
                } label: {
                    row(String(localized: "Pick a date and time"), value: nil, systemImage: "calendar")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("reminder.pick")
                if picksTime { picker }
            }
            if let problem {
                Text(problem).font(.footnote).foregroundStyle(Palette.warnText).accessibilityIdentifier("reminder.problem")
            }
            if notifications.authorization == .denied {
                Label("Notifications are off for Cue in iOS Settings. The reminder is kept here in Cue.", systemImage: "bell.slash")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            existing
        }
        .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
        .disabled(isSaving)
        .fittedSheet()
        .task {
            picksTime = startsPicking || editing != nil
            if let editing, let date = editing.time.date(in: calendar) { picked = date }
            await notifications.refreshAuthorization()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reminder.sheet")
    }

    // MARK: - Parts

    private func choice(_ label: String, _ time: LocalDateTime, id: String) -> some View {
        let date = time.date(in: calendar) ?? .now
        return Button { set(time) } label: {
            row(label, value: date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(.interface)), systemImage: "bell")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func row(_ label: String, value: String?, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).foregroundStyle(Palette.ink2).frame(width: 22).accessibilityHidden(true)
            Text(label).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            if let value { Text(value).foregroundStyle(Palette.ink2) }
        }
        .font(.body)
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker("Date and time", selection: $picked, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                .foregroundStyle(Palette.ink)
                .tint(Palette.accText)
                .accessibilityIdentifier("reminder.datePicker")
            if notifications.isInQuietHours(pickedTime) {
                Text("This is during your quiet hours. Cue will remind you anyway, since you chose this time.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("reminder.quietNote")
            }
            Button { set(pickedTime) } label: { Text("Set reminder").frame(maxWidth: .infinity) }
                .buttonStyle(.cuePrimary())
                .accessibilityIdentifier("reminder.set")
        }
        .padding(16)
    }

    /// The reminders already set for this script, take or network, each with ✕.
    @ViewBuilder
    private var existing: some View {
        let set = notifications.reminders(about: subject).filter { $0.id != editing?.id }
        if !set.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Already set").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink2)
                ForEach(set) { reminder in
                    HStack {
                        Text(reminder.time.date(in: calendar).map { ReminderFeedback.when($0) } ?? "")
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Button(role: .destructive) { notifications.cancelReminder(reminder.id) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.ink2)
                        }
                        .accessibilityLabel(Text("Remove reminder"))
                        .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    }
                }
            }
        }
    }

    // MARK: - Setting

    private func set(_ time: LocalDateTime) {
        guard !ReminderChoice.isPast(time, now: .now, calendar: calendar) else {
            problem = String(localized: "Pick a time in the future")
            return
        }
        isSaving = true
        Task {
            let result = await notifications.setReminder(subject, title: title, at: time, replacing: editing?.id)
            isSaving = false
            if result == .past {
                problem = String(localized: "Pick a time in the future")
                return
            }
            dismiss()
            onSet(result)
        }
    }
}

#if DEBUG
#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ReminderSheet(subject: .script(UUID()), title: "3 morning habits")
    }
    .previewEnvironment()
}
#endif
