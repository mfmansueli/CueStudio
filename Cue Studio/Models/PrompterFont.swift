//
//  PrompterFont.swift
//  Cue Studio
//

import Foundation

nonisolated enum PrompterFont: String, Codable, CaseIterable, Identifiable, Sendable {
    case lexend, legible, serif, rounded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lexend: String(localized: "Lexend")
        case .legible: String(localized: "Legible")
        case .serif: String(localized: "Serif")
        case .rounded: String(localized: "Rounded")
        }
    }
}
