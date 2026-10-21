//
//  NotificationRoutineEditor.swift
//  Cue Studio
//

import SwiftUI

/// "Remind me to create", opened under its switch: the days (a chip for each, in the iPhone's week order) and the time. The chips arrive one
/// after another when the routine is switched on, and each answers its tap with a tick and a small spring; the last day can't be taken away.
struct NotificationRoutineEditor: View {
    let routine: CreationRoutine
    let onChange: (CreationRoutine) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    private var calendar: Calendar { .current }

    /// The weekdays from the first day of the iPhone's week.
    private var weekdays: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    private var time: Binding<Date> {
        Binding(
            get: { calendar.date(bySettingHour: routine.hour, minute: routine.minute, second: 0, of: .now) ?? .now },
            set: { date in
                let parts = calendar.dateComponents([.hour, .minute], from: date)
                onChange(CreationRoutine(weekdays: routine.weekdays, hour: parts.hour ?? 18, minute: parts.minute ?? 0))
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(weekdays.enumerated()), id: \.element) { index, weekday in
                    day(weekday)
                        .scaleEffect(arrived ? 1 : 0.5)
                        .opacity(arrived ? 1 : 0)
                        .animation(.spring(response: 0.42, dampingFraction: 0.68).delay(Double(index) * 0.035), value: arrived)
                }
            }
            Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.trailing, -16)
            DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                .foregroundStyle(Palette.ink)
                .tint(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("notifications.routine.time")
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .onAppear {
            if reduceMotion { arrived = true } else { Task { @MainActor in arrived = true } }
        }
    }

    private func day(_ weekday: Int) -> some View {
        let isOn = routine.weekdays.contains(weekday)
        return Button {
            var days = routine.weekdays
            if isOn { days.remove(weekday) } else { days.insert(weekday) }
            guard !days.isEmpty else {
                Haptics.rigid()
                return
            }
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) {
                onChange(CreationRoutine(weekdays: days, hour: routine.hour, minute: routine.minute))
            }
        } label: {
            Text(calendar.veryShortStandaloneWeekdaySymbols[weekday - 1])
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                .foregroundStyle(isOn ? Palette.accInk : Palette.ink)
                .background(isOn ? Palette.acc : Palette.surface3, in: Circle())
                .scaleEffect(isOn ? 1 : 0.92)
        }
        .buttonStyle(.cuePress)
        .accessibilityLabel(Text(calendar.standaloneWeekdaySymbols[weekday - 1]))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("notifications.routine.day.\(weekday)")
    }
}
