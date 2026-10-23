//
//  LowPowerNotice.swift
//  Cue Studio
//

import Foundation

/// When the editor says Low Power Mode is on (the screen at 60 frames per second, editing and exports slower): while the
/// mode is on, at most once a day, so whoever edits with it on by choice isn't told every time.
nonisolated enum LowPowerNotice {
    static func shows(isLowPower: Bool, lastShown: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard isLowPower else { return false }
        guard let lastShown else { return true }
        return !calendar.isDate(lastShown, inSameDayAs: now)
    }
}
