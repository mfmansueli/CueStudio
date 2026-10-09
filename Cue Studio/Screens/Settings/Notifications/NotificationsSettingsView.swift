//
//  NotificationsSettingsView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Notifications: whether iOS allows Cue (a switch, `NotificationPermissionSection`), the five kinds of notification (tools and
/// news start off), the routine's days and time, the reminders set (edit with a tap, remove with a swipe), quiet hours, a pause for the
/// automatic ones, and whether a project's title may appear in a notification (off: "your script"). A Debug build adds what is scheduled
/// and counted.
struct NotificationsSettingsView: View {
    @Environment(NotificationService.self) private var notifications
    @Environment(\.scenePhase) private var scenePhase

    @State private var editing: Reminder?

    private var calendar: Calendar { .current }

    var body: some View {
        List {
            NotificationPermissionSection()
            categories
            if notifications.isOn(.routine) { routine }
            reminders
            automatic
            Section {
                SettingsListToggle(
                    title: String(localized: "Show titles in previews"),
                    detail: String(localized: "Off: “your script” instead of its name"),
                    isOn: Binding(get: { notifications.state.showsTitles }, set: { notifications.setShowsTitles($0) })
                )
                .cardRowBackground(position: .only)
                .accessibilityIdentifier("notifications.showsTitles")
            } footer: {
                Text("Scripts, comments and your imported writing are never in a notification.")
            }
            #if DEBUG
            NotificationDiagnosticsSection()
            #endif
        }
        .cueGroupedList()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
        .task { await notifications.refreshAuthorization() }
        .onChange(of: scenePhase) { _, phase in
            // Back from iOS Settings: what it allows may have changed.
            if phase == .active { Task { await notifications.refreshAuthorization() } }
        }
        .sheet(item: $editing) { reminder in
            ReminderSheet(subject: reminder.subject, title: reminder.title, editing: reminder)
        }
        .accessibilityIdentifier("notifications.screen")
    }

    // MARK: - Sections

    private var categories: some View {
        Section {
            ForEach(Array(NotificationCategory.allCases.enumerated()), id: \.element) { index, category in
                SettingsListToggle(title: category.title, detail: category.detail, isOn: binding(for: category))
                    .cardRowBackground(position: CardRowPosition(index: index, count: NotificationCategory.allCases.count))
                    .accessibilityIdentifier("notifications.category.\(category.rawValue)")
            }
        } header: {
            CueSectionHeader(verbatim: String(localized: "What Cue sends"))
        } footer: {
            Text("Tools and news stay off until you turn them on.")
        }
    }

    private var routine: some View {
        Section {
            NotificationRoutineEditor(
                routine: notifications.state.routine ?? CreationRoutine(),
                isInQuietHours: notifications.state.quietHours.contains(minuteOfDay: (notifications.state.routine ?? CreationRoutine()).minuteOfDay)
            ) { routine in
                Task { await notifications.setRoutine(routine) }
            }
            .cardRowBackground(position: .only)
        } header: {
            CueSectionHeader(verbatim: String(localized: "Days and time"))
        } footer: {
            Text("On those days Cue opens on your next step.")
        }
    }

    @ViewBuilder
    private var reminders: some View {
        let list = notifications.upcomingReminders
        Section {
            if list.isEmpty {
                Text("No reminders. Set one from a script, a recording, or Post later.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .frame(minHeight: Metrics.listRowContent)
                    .cardRowBackground(position: .only)
                    .accessibilityIdentifier("notifications.noReminders")
            }
            ForEach(Array(list.enumerated()), id: \.element.id) { index, reminder in
                Button { editing = reminder } label: { NotificationReminderRow(reminder: reminder) }
                    .buttonStyle(.plain)
                    .cardRowBackground(position: CardRowPosition(index: index, count: list.count))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { notifications.cancelReminder(reminder.id) } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        } header: {
            CueSectionHeader(verbatim: String(localized: "My reminders"))
        }
    }

    private var automatic: some View {
        Section {
            quietTime(String(localized: "Quiet from"), minute: \.startMinute, id: "notifications.quietStart")
                .cardRowBackground(position: .first)
            quietTime(String(localized: "Until"), minute: \.endMinute, id: "notifications.quietEnd")
                .cardRowBackground(position: .middle)
            pauseRow.cardRowBackground(position: .last)
        } header: {
            CueSectionHeader(verbatim: String(localized: "Automatic notifications"))
        } footer: {
            Text("At most one a day and two a week. Your reminders and routine aren’t affected.")
        }
    }

    private func quietTime(_ title: String, minute: WritableKeyPath<QuietHours, Int>, id: String) -> some View {
        let binding = Binding<Date>(
            get: {
                let value = notifications.state.quietHours[keyPath: minute]
                return calendar.date(bySettingHour: value / 60, minute: value % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = calendar.dateComponents([.hour, .minute], from: date)
                var hours = notifications.state.quietHours
                hours[keyPath: minute] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                notifications.setQuietHours(QuietHours(startMinute: hours.startMinute, endMinute: hours.endMinute))
            }
        )
        return DatePicker(title, selection: binding, displayedComponents: .hourAndMinute)
            .foregroundStyle(Palette.ink)
            .tint(Palette.accText)
            .frame(minHeight: Metrics.listRowContent)
            .accessibilityIdentifier(id)
    }

    private var pauseRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pause automatic notifications").foregroundStyle(Palette.ink)
                if let until = notifications.pausedUntil {
                    Text("Paused until \(until.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(.interface)))")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
            }
            Spacer(minLength: 8)
            Menu {
                Button("7 days") { notifications.pauseAutomatic(days: 7) }
                Button("30 days") { notifications.pauseAutomatic(days: 30) }
                if notifications.pausedUntil != nil { Button("Resume now") { notifications.resumeAutomatic() } }
            } label: {
                Text(notifications.pausedUntil == nil ? String(localized: "Pause for…") : String(localized: "Change"))
                    .foregroundStyle(Palette.accText)
            }
            .accessibilityIdentifier("notifications.pause")
        }
        .frame(minHeight: Metrics.listRowContent)
    }

    private func binding(for category: NotificationCategory) -> Binding<Bool> {
        Binding(
            get: { notifications.isOn(category) },
            set: { isOn in
                Task {
                    if category == .routine, isOn, notifications.state.routine == nil {
                        await notifications.setRoutine(CreationRoutine())
                    } else {
                        await notifications.setCategory(category, isOn: isOn)
                    }
                }
            }
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack { NotificationsSettingsView() }
        .previewEnvironment()
}
#endif
