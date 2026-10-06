//
//  Niche.swift
//  Cue Studio
//

import Foundation

/// What a creator talks about. The first ten are the topics the first flight offers (1.2) and My Cue Voice shows (2.2), most common first
/// (09 §14b: the ranking is the designer's estimate); `wellness` and `education` stay for creators who already chose them.
nonisolated enum Niche: String, Codable, CaseIterable, Identifiable, Sendable {
    case fitness, food, beauty, fashion, finance, tech, travel, productivity, parenting, lifestyle, wellness, education

    var id: String { rawValue }

    /// The topics the first flight offers, in order.
    static let offered = Array(allCases.prefix(10))

    /// Short name: script tags, idea lines, prompts.
    var label: String {
        switch self {
        case .lifestyle: String(localized: "Lifestyle")
        case .wellness: String(localized: "Wellness")
        case .beauty: String(localized: "Beauty")
        case .fitness: String(localized: "Fitness")
        case .food: String(localized: "Food")
        case .tech: String(localized: "Tech")
        case .finance: String(localized: "Finance")
        case .education: String(localized: "Education")
        case .fashion: String(localized: "Fashion")
        case .travel: String(localized: "Travel")
        case .productivity: String(localized: "Productivity")
        case .parenting: String(localized: "Parenting")
        }
    }

    /// The topic's name as a chip and as a world in the universe (the board's ten topics): what the creator picked is what they see everywhere.
    var chipLabel: String {
        switch self {
        case .fitness: String(localized: "Fitness & wellness")
        case .food: String(localized: "Food & cooking")
        case .beauty: String(localized: "Beauty & skincare")
        case .fashion: String(localized: "Fashion & style")
        case .finance: String(localized: "Personal finance")
        case .tech: String(localized: "Tech & AI")
        case .travel: String(localized: "Budget travel")
        case .productivity: String(localized: "Productivity & career")
        case .parenting: String(localized: "Parenting & family")
        case .lifestyle: String(localized: "Morning routines")
        case .wellness: String(localized: "Wellness")
        case .education: String(localized: "Education")
        }
    }
}
