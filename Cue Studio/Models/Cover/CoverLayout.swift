//
//  CoverLayout.swift
//  Cue Studio
//

import Foundation

/// How a cover's words are laid out (v26 Cover › Text).
nonisolated enum CoverLayout: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Big words with one highlighted.
    case hook
    /// A big number from the title, then the rest (a listicle).
    case number
    /// A small "PART 3 · WORD" tag above the title (a series).
    case kicker
    /// The title as a question, in a dark box.
    case question
    /// No title: BEFORE and AFTER labels on a split picture (a result).
    case beforeAfter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hook: String(localized: "Hook")
        case .number: String(localized: "Number")
        case .kicker: String(localized: "Kicker")
        case .question: String(localized: "Question")
        case .beforeAfter: String(localized: "Before/After")
        }
    }

    /// What it is for, in the tile's mono caption.
    var purpose: String {
        switch self {
        case .hook: String(localized: "Big + highlight")
        case .number: String(localized: "Listicle")
        case .kicker: String(localized: "Series")
        case .question: String(localized: "Curiosity")
        case .beforeAfter: String(localized: "Result")
        }
    }

    /// The glyph on the tile.
    var glyph: String {
        switch self {
        case .hook: "AA"
        case .number: "3"
        case .kicker: "D12"
        case .question: "?"
        case .beforeAfter: "B|A"
        }
    }

    /// Where the words start, as a share of the cover's height from the top.
    var textTop: Double {
        switch self {
        case .number: 0.18
        case .kicker: 0.26
        case .hook, .question, .beforeAfter: 0.30
        }
    }

    /// The size of the words, as a share of the cover's width.
    var wordSize: Double {
        switch self {
        case .number, .question: 0.105
        case .hook, .kicker, .beforeAfter: 0.135
        }
    }

    var showsTitle: Bool { self != .beforeAfter }
}
