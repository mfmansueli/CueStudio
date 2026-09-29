//
//  TextOverlayWeight.swift
//  Cue Studio
//

import Foundation

nonisolated enum TextOverlayWeight: String, Codable, CaseIterable, Identifiable, Sendable {
    case regular, semibold, bold, heavy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .regular: String(localized: "Regular")
        case .semibold: String(localized: "Semibold")
        case .bold: String(localized: "Bold")
        case .heavy: String(localized: "Heavy")
        }
    }
}
