//
//  VoiceQuestionState.swift
//  Cue Studio
//

import Foundation

/// What the My Cue Voice tip remembers on this device (08 §5): which days the app was opened, when tips were shown, what was
/// snoozed, skipped or pulled forward. One value, kept as JSON.
nonisolated struct VoiceQuestionState: Codable, Equatable, Sendable {
    /// The days (`yyyy-MM-dd`) the app was opened, until there are two: the tip waits for the creator to come back.
    var firstEligibleDays: [String] = []
    /// When a tip was shown, over the last seven days.
    var shownDates: [Date] = []
    /// When each snoozed question may come back, by `VoiceQuestion.rawValue`.
    var snoozedUntil: [String: Date] = [:]
    /// How many times each question was dismissed without an answer.
    var dismissCount: [String: Int] = [:]
    var consecutiveDismissals = 0
    /// All tips wait until then (three dismissals in a row).
    var pausedUntil: Date?
    /// "None of these": never asked again (it can still be answered on the full page).
    var skipped: Set<String> = []
    /// The moments that already pulled a question forward, in the order they happened.
    var pulledForward: [String] = []
    var completeToastShown = false
    /// The scripts written in the creator's voice (ids): the example question waits for two of them.
    var voiceScriptIDs: [String] = []
    /// How many times a script written in their voice was edited afterwards (the second pulls a question forward).
    var generatedEdits = 0
    /// How many tips of each question TipKit has already spent (opened or closed): TipKit never shows an invalidated tip again, so the
    /// next one of that question is a tip of its own.
    var tipRounds: [String: Int] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstEligibleDays = try container.decodeIfPresent([String].self, forKey: .firstEligibleDays) ?? []
        shownDates = try container.decodeIfPresent([Date].self, forKey: .shownDates) ?? []
        snoozedUntil = try container.decodeIfPresent([String: Date].self, forKey: .snoozedUntil) ?? [:]
        dismissCount = try container.decodeIfPresent([String: Int].self, forKey: .dismissCount) ?? [:]
        consecutiveDismissals = try container.decodeIfPresent(Int.self, forKey: .consecutiveDismissals) ?? 0
        pausedUntil = try container.decodeIfPresent(Date.self, forKey: .pausedUntil)
        skipped = try container.decodeIfPresent(Set<String>.self, forKey: .skipped) ?? []
        pulledForward = try container.decodeIfPresent([String].self, forKey: .pulledForward) ?? []
        completeToastShown = try container.decodeIfPresent(Bool.self, forKey: .completeToastShown) ?? false
        voiceScriptIDs = try container.decodeIfPresent([String].self, forKey: .voiceScriptIDs) ?? []
        generatedEdits = try container.decodeIfPresent(Int.self, forKey: .generatedEdits) ?? 0
        tipRounds = try container.decodeIfPresent([String: Int].self, forKey: .tipRounds) ?? [:]
    }
}
