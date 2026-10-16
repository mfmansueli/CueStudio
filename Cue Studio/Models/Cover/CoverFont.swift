//
//  CoverFont.swift
//  Cue Studio
//

import Foundation

/// The typeface of a cover's words: a tall condensed one, or the editor's families.
nonisolated enum CoverFont: String, Codable, CaseIterable, Identifiable, Sendable {
    case anton, grotesk, serif, system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anton: "Anton"
        case .grotesk: "Grotesk"
        case .serif: "Serif"
        case .system: "SF Pro"
        }
    }
}
