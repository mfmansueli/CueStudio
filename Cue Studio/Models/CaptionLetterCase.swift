//
//  CaptionLetterCase.swift
//  Cue Studio
//

import Foundation

/// The caption's letters as typed, all capitals or all small (Caption style › Adjust › Case), each as the line's language
/// writes them (Turkish "İ" and "ı"). Scripts without capitals stay as they are.
nonisolated enum CaptionLetterCase: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CaptionLetterCase.asTyped

    case asTyped, upper, lower

    var id: String { rawValue }

    /// Shown as the letters themselves: "Aa", "AA", "aa".
    var label: String {
        switch self {
        case .asTyped: String(localized: "Aa", comment: "Caption letter case: as typed")
        case .upper: String(localized: "AA", comment: "Caption letter case: all capitals")
        case .lower: String(localized: "aa", comment: "Caption letter case: all small letters")
        }
    }

    /// Read aloud instead of the letters.
    var accessibilityLabel: String {
        switch self {
        case .asTyped: String(localized: "As typed")
        case .upper: String(localized: "All capitals")
        case .lower: String(localized: "All small letters")
        }
    }

    /// `text` in this case.
    func shown(_ text: String) -> String {
        switch self {
        case .asTyped: text
        case .upper: TextShaping.uppercased(text)
        case .lower: TextShaping.lowercased(text)
        }
    }

    /// One piece of `line` in the case the whole line is written in.
    func shown(_ piece: String, locale: Locale?) -> String {
        switch self {
        case .asTyped: piece
        case .upper: TextShaping.uppercased(piece, locale: locale)
        case .lower: TextShaping.lowercased(piece, locale: locale)
        }
    }
}
