//
//  Niche.swift
//  Cue Studio
//

import Foundation

nonisolated enum Niche: String, Codable, CaseIterable, Identifiable, Sendable {
    case lifestyle, wellness, beauty, fitness, food, tech, finance, education

    var id: String { rawValue }

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
        }
    }
}
