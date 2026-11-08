//
//  CoverTitleSection.swift
//  Cue Studio
//

import Foundation

/// The Title step's parts, picked under the field: the words (which stand out, the line above), the type, the colors and the box
/// behind them (none, shadow, outline or a box). Words first: with the keyboard up, it is what comes after typing.
enum CoverTitleSection: String, CaseIterable, Identifiable {
    case words, type, color, box

    var id: String { rawValue }

    var label: String {
        switch self {
        case .words: String(inInterfaceLanguage: LocalizedStringResource(
            "coverStudio.title.words", defaultValue: "Words",
            comment: "Cover Studio › Title: the tab with the words that stand out and the small line above the title. A noun, short."
        ))
        case .type: String(localized: "Type", comment: "Cover Studio: the title's typography group")
        case .color: String(localized: "Color")
        case .box: String(localized: "Box")
        }
    }
}
