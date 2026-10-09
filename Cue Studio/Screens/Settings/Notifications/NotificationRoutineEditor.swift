//
//  NotificationRoutineEditor.swift
//  Cue Studio
//

import SwiftUI

/// "My creation routine": the days (a chip for each, in the iPhone's week order) and the time. A time inside the quiet hours is kept (the
/// creator chose it) and said.
struct NotificationRoutineEditor: View {
    let routine: CreationRoutine
    let isInQuietHours: Bool
    let onChange: (CreationRoutine) -> Void

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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(weekdays, id: \.self) { weekday in
                    let isOn = routine.weekdays.contains(weekday)
                    Button {
                        var days = routine.weekdays
                        if isOn { days.remove(weekday) } else { days.insert(weekday) }
                        guard !days.isEmpty else { return }
                        onChange(CreationRoutine(weekdays: days, hour: routine.hour, minute: routine.minute))
                    } label: {
                        Text(calendar.veryShortStandaloneWeekdaySymbols[weekday - 1])
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                            .foregroundStyle(isOn ? Palette.accInk : Palette.ink)
                            .background(isOn ? Palette.acc : Palette.surface3, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(calendar.standaloneWeekdaySymbols[weekday - 1]))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("notifications.routine.day.\(weekday)")
                }
            }
            DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                .foregroundStyle(Palette.ink)
                .tint(Palette.accText)
                .accessibilityIdentifier("notifications.routine.time")
            if isInQuietHours {
                Text("This is during your quiet hours. Your routine still rings, since you chose this time.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
    }
}
