//
//  ProPlan.swift
//  Cue Studio
//

import Foundation

/// Cue Pro purchase options. Prices come from the App Store; these are identifiers and copy only.
nonisolated enum ProPlan: String, Codable, CaseIterable, Identifiable, Sendable {
    case annual, monthly, lifetime

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .annual: "studio.cue.pro.annual"
        case .monthly: "studio.cue.pro.monthly"
        case .lifetime: "studio.cue.pro.lifetime"
        }
    }

    init?(productID: String) {
        guard let plan = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = plan
    }

    var label: String {
        switch self {
        case .annual: String(localized: "Annual")
        case .monthly: String(localized: "Monthly")
        case .lifetime: String(localized: "Lifetime")
        }
    }

    var isSubscription: Bool { self != .lifetime }
}
