//
//  TakeDay.swift
//  Cue Studio
//

import Foundation

/// Section of the Takes library.
nonisolated enum TakeDay: String, CaseIterable, Identifiable, Sendable {
    case today, yesterday, earlier

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: String(localized: "Today")
        case .yesterday: String(localized: "Yesterday")
        case .earlier: String(localized: "Earlier")
        }
    }

    init(date: Date, now: Date, calendar: Calendar) {
        if calendar.isDate(date, inSameDayAs: now) {
            self = .today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            self = .yesterday
        } else {
            self = .earlier
        }
    }
}
