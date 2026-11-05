//
//  ReviewPromptPolicy.swift
//  Cue Studio
//

import Foundation

/// When Cue asks for an App Store rating (owner, 05/11/2026): only with Apple's own prompt (App Review 5.6.1), after a video left Cue on a day
/// other than the one Cue was installed, and not the first video; once per version of the app; never on a day an export failed, never when
/// the free exports just ran out, never with anything offered for it. iOS itself shows it at most three times a year.
nonisolated struct ReviewPromptPolicy: Codable, Equatable, Sendable {
    /// The day Cue first opened, as "2026-11-05".
    var installDay: String?
    /// Videos that left Cue since this was kept.
    var deliveries = 0
    /// The version the prompt was last asked in.
    var askedVersion: String?
    /// The last day an export failed.
    var failureDay: String?

    static let deliveriesBefore = 2

    /// After one more video left Cue: whether to ask now. `exportsLeft` is nil on Pro.
    func asks(today: String, version: String, exportsLeft: Int?) -> Bool {
        deliveries >= Self.deliveriesBefore
            && installDay.map { $0 != today } ?? false
            && askedVersion != version
            && failureDay != today
            && exportsLeft != 0
    }

    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
