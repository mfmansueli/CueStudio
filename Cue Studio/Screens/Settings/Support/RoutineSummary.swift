//
//  RoutineSummary.swift
//  Cue Studio
//

import Foundation

/// A creation routine in a line, "Mon, Wed, and Fri · 6:00 PM": its days in the iPhone's week order and its time, in the interface
/// language. The routine's switch shows it while off, so turning it on is a choice the creator saw (owner, 30/10/2026).
enum RoutineSummary {
    static func text(for routine: CreationRoutine, calendar: Calendar = .current, locale: Locale = .interface) -> String {
        var calendar = calendar
        calendar.locale = locale
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        let symbols = calendar.shortWeekdaySymbols
        let days = order.filter(routine.weekdays.contains).map { symbols[$0 - 1] }
        let time = calendar.date(bySettingHour: routine.hour, minute: routine.minute, second: 0, of: .now)
            .map { $0.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)) } ?? ""
        return days.formatted(.list(type: .and).locale(locale)) + " · " + time
    }
}
