//
//  ContentGoal.swift
//  Cue Studio
//

import Foundation

/// What the creator's videos are for (My Cue Voice · Personality, "My videos are for"): the script's payoff and call to action lean toward it.
nonisolated enum ContentGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case grow, sell, teach, entertain, winClients, community, raiseAwareness

    var id: String { rawValue }

    /// The most the creator can pick.
    static let limit = 2

    var label: String {
        switch self {
        case .grow: String(localized: "Grow my audience")
        case .sell: String(localized: "Sell something")
        case .teach: String(localized: "Teach")
        case .entertain: String(localized: "Entertain")
        case .winClients: String(localized: "Win clients")
        case .community: String(localized: "Build a community")
        case .raiseAwareness: String(localized: "Raise awareness")
        }
    }

    /// What the AI reads (English, whatever the interface language is).
    var promptPhrase: String {
        switch self {
        case .grow: "grow their audience"
        case .sell: "sell a product or service"
        case .teach: "teach something useful"
        case .entertain: "entertain"
        case .winClients: "win new clients"
        case .community: "build a community"
        case .raiseAwareness: "raise awareness of a cause"
        }
    }
}
