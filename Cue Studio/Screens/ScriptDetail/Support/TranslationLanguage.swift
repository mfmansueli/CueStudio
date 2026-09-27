//
//  TranslationLanguage.swift
//  Cue Studio
//

import Foundation

/// Languages offered by the Translate tool.
nonisolated enum TranslationLanguage: String, CaseIterable, Identifiable, Sendable {
    case spanish, portuguese, french, german, italian

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spanish: String(localized: "Spanish")
        case .portuguese: String(localized: "Portuguese")
        case .french: String(localized: "French")
        case .german: String(localized: "German")
        case .italian: String(localized: "Italian")
        }
    }

    /// English name used in the model prompt.
    var promptName: String { rawValue.capitalized }
}
