//
//  ArrivalSchedule.swift
//  Cue Studio
//

import Foundation

/// One line's share of a text that arrives a line at a time (`ArrivingLines`): its words' slots on the one clock of the whole text, so a
/// line never starts before the words above it have, and when the caret is on it.
nonisolated struct ArrivalSchedule: Equatable, Sendable {
    /// When each word of the line arrives.
    var times: [Double]
    /// The caret is on this line from when its first word starts (nil: from the start, for the first line)…
    var caretFrom: Double?
    /// …until the first word of the line below starts (nil: for good, for the last line).
    var caretUntil: Double?

    func holdsCaret(at now: Double) -> Bool {
        (caretFrom.map { now >= $0 } ?? true) && (caretUntil.map { now < $0 } ?? true)
    }

    /// Each line's schedule, from how many words each line has (`counts`) and every word's slot in order (`times`).
    static func split(_ times: [Double], counts: [Int]) -> [ArrivalSchedule] {
        var start = 0
        return counts.enumerated().map { index, count in
            let lower = min(start, times.count)
            let upper = min(start + count, times.count)
            defer { start += count }
            return ArrivalSchedule(
                times: Array(times[lower..<upper]),
                caretFrom: index == 0 ? nil : (lower < times.count ? times[lower] : .infinity),
                caretUntil: upper < times.count ? times[upper] : nil
            )
        }
    }
}
