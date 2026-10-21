//
//  NotificationsSettingsView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Notifications (owner's redesign, 22/10/2026: short and direct). On top, whether iOS lets Cue speak, as a switch
/// (`NotificationPermissionRow`); switched on the first time, everything turns on together: the bell rings and takes a ✓, and the switches
/// below light one after another with a tick each. Then **From Cue** (two switches,
/// `NotificationGroup`), **Creation routine** (its switch opens the days and the time) and **Your reminders** (they always arrive; edit with
/// a tap, remove with a swipe). Quiet hours (9 PM to 9 AM), the caps and the titles kept out of notifications are Cue's, not choices. A Debug
/// build adds what is scheduled and counted.
struct NotificationsSettingsView: View {
    @Environment(NotificationService.self) private var notifications
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var editing: Reminder?
    /// iOS is being asked: the switches hold still until it answers.
    @State private var isAsking = false
    @State private var rangAt: Date?
    /// How many switches show their state: during the cascade they light one by one.
    @State private var lit = NotificationGroup.allCases.count

    private var canSchedule: Bool { notifications.authorization.canSchedule && !isAsking }

    private var mood: NotificationPermissionRow.Mood {
        if isAsking { return .notAsked }
        switch notifications.authorization {
        case .notDetermined: return .notAsked
        case .denied: return .refused
        case .provisional: return .quiet
        case .authorized, .ephemeral: return .allowed
        }
    }

    /// The switch on top: what iOS allows. Switched on while never asked, iOS asks; any other change opens Cue in iOS Settings.
    private var permission: Binding<Bool> {
        Binding(
            get: { isAsking || notifications.authorization.canSchedule },
            set: { wants in
                if wants, notifications.authorization == .notDetermined { turnOn() } else { openSettings() }
            }
        )
    }

    var body: some View {
        List {
            Section {
                NotificationPermissionRow(mood: mood, rangAt: rangAt, isOn: permission)
                    .listRowInsets(EdgeInsets())
                    .cardRowBackground(position: .only)
            }
            fromCue
            routine
            reminders
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
        .onChange(of: notifications.authorization) { old, new in
            // Allowed in iOS Settings after a no: as the first time, everything turns on.
            guard old == .denied, new.canSchedule else { return }
            lit = 0
            notifications.turnEverythingOn()
            celebrate()
        }
        .sheet(item: $editing) { reminder in
            ReminderSheet(subject: reminder.subject, title: reminder.title, editing: reminder)
        }
        .accessibilityIdentifier("notifications.screen")
    }

    // MARK: - From Cue and the routine

    /// The order the switches light in when everything turns on: as they stand on the page.
    private static let order: [NotificationGroup] = [.finish, .news, .routine]

    private var fromCue: some View {
        let groups: [NotificationGroup] = [.finish, .news]
        return Section {
            ForEach(Array(groups.enumerated()), id: \.element) { index, group in
                NotificationGroupRow(group: group, isOn: binding(for: group))
                    .listRowInsets(EdgeInsets())
                    .cardRowBackground(position: CardRowPosition(index: index, count: groups.count))
            }
        } header: {
            CueSectionHeader(verbatim: String(localized: "From Cue"))
        } footer: {
            Text("At most one a day, never at night. Your reminders always arrive.")
        }
    }

    private var routine: some View {
        let opens = isLit(.routine) && notifications.isOn(.routine)
        return Section {
            VStack(spacing: 0) {
                NotificationGroupRow(group: .routine, isOn: binding(for: .routine))
                if opens, let routine = notifications.state.routine {
                    NotificationRoutineEditor(routine: routine) { routine in
                        Task { await notifications.setRoutine(routine) }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: opens)
            .listRowInsets(EdgeInsets())
            .cardRowBackground(position: .only)
        } header: {
            CueSectionHeader(verbatim: String(localized: "Creation routine"))
        }
    }

    /// The switch shows its state: iOS lets Cue speak and, during the cascade, its turn has come.
    private func isLit(_ group: NotificationGroup) -> Bool {
        canSchedule && (Self.order.firstIndex(of: group) ?? 0) < lit
    }

    private func binding(for group: NotificationGroup) -> Binding<Bool> {
        Binding(
            get: { isLit(group) && notifications.isGroupOn(group) },
            set: { isOn in
                switch notifications.authorization {
                case .notDetermined:
                    turnOn()
                case .denied:
                    openSettings()
                case .authorized, .provisional, .ephemeral:
                    if isOn { HapticPatterns.playChime() } else { Haptics.selection() }
                    Task {
                        await notifications.setGroup(group, isOn: isOn)
                    }
                }
            }
        )
    }

    // MARK: - Allowing

    /// The switch on top (or one below) while iOS was never asked: iOS asks once; its yes turns everything on, and the page celebrates it.
    private func turnOn() {
        guard !isAsking else { return }
        isAsking = true
        lit = 0
        Task {
            let answer = await notifications.allowEverything()
            if answer.canSchedule {
                celebrate()
            } else {
                lit = NotificationGroup.allCases.count
            }
            isAsking = false
        }
    }

    /// The bell rings and takes its ✓; the switches light one after another, each with its tick (`HapticPatterns.notificationsOn`).
    private func celebrate() {
        let count = NotificationGroup.allCases.count
        HapticPatterns.playNotificationsOn()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { rangAt = .now }
        Task { @MainActor in
            // The ring is over: the bell rests (and its clock stops).
            try? await Task.sleep(for: .seconds(1.5))
            rangAt = nil
        }
        guard !reduceMotion else {
            lit = count
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(NotificationsCascade.firstSwitch))
            for step in 1...count {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { lit = step }
                try? await Task.sleep(for: .seconds(NotificationsCascade.step))
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
    }

    // MARK: - Your reminders

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
            CueSectionHeader(verbatim: String(localized: "Your reminders"))
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { NotificationsSettingsView() }
        .previewEnvironment()
}
#endif
