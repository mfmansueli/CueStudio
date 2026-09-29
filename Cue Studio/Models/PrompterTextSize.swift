//
//  PrompterTextSize.swift
//  Cue Studio
//

import Foundation

/// The three text sizes Creator Setup offers. The slider in Display still reaches any size in
/// `PrompterSettings.sizeRange`.
nonisolated enum PrompterTextSize: String, CaseIterable, Identifiable, Sendable {
    case small, medium, large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: String(localized: "Small")
        case .medium: String(localized: "Medium")
        case .large: String(localized: "Large")
        }
    }

    /// Selfie size in points (Studio reads it 1.35× bigger). Medium is the prompter's default.
    var points: Double {
        switch self {
        case .small: 22
        case .medium: 28
        case .large: 36
        }
    }

    /// The preset a size matches, if any.
    init?(points: Double) {
        guard let match = Self.allCases.first(where: { abs($0.points - points) < 0.5 }) else { return nil }
        self = match
    }
}
