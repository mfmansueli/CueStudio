//
//  Swearing.swift
//  Cue Studio
//

import Foundation

/// How much swearing My Cue Voice may write. Strong swearing and slurs are never written whatever this says (Apple
/// Intelligence won't generate them).
nonisolated enum Swearing: String, Codable, CaseIterable, Identifiable, Sendable {
    case never, mild

    var id: String { rawValue }

    var label: String {
        switch self {
        case .never: String(localized: "Never")
        case .mild: String(localized: "Mild only")
        }
    }
}
