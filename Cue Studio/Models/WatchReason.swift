//
//  WatchReason.swift
//  Cue Studio
//

import Foundation

/// Why the creator's audience watches them (My Cue Voice · Who's watching, "Why do they watch you?"): it shapes the hook and the payoff.
nonisolated enum WatchReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case learn, getInspired, solveProblem, laugh, feelUnderstood, decideToBuy

    var id: String { rawValue }

    /// The most the creator can pick.
    static let limit = 2

    var label: String {
        switch self {
        case .learn: String(localized: "Learn something")
        case .getInspired: String(localized: "Get inspired")
        case .solveProblem: String(localized: "Solve a problem")
        case .laugh: String(localized: "Have a laugh")
        case .feelUnderstood: String(localized: "Feel understood")
        case .decideToBuy: String(localized: "Decide what to buy")
        }
    }

    /// What the AI reads (English, whatever the interface language is).
    var promptPhrase: String {
        switch self {
        case .learn: "learn something"
        case .getInspired: "get inspired"
        case .solveProblem: "solve a problem"
        case .laugh: "have a laugh"
        case .feelUnderstood: "feel understood"
        case .decideToBuy: "decide what to buy"
        }
    }
}
