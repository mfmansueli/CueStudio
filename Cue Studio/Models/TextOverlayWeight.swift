//
//  TextOverlayWeight.swift
//  Cue Studio
//

import Foundation

nonisolated enum TextOverlayWeight: String, Codable, CaseIterable, Identifiable, Sendable {
    case regular, medium, semibold, bold, heavy

    /// The weights Text style offers (400, 500, 700, 800).
    static let editorWeights: [TextOverlayWeight] = [.regular, .medium, .bold, .heavy]

    /// The CSS-style number: 400 regular … 800 heavy.
    var value: Double {
        switch self {
        case .regular: 400
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        }
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .regular: String(localized: "Regular")
        case .medium: String(localized: "Medium")
        case .semibold: String(localized: "Semibold")
        case .bold: String(localized: "Bold")
        case .heavy: String(localized: "Heavy")
        }
    }
}
