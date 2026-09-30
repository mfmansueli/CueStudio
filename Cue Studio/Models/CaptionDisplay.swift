//
//  CaptionDisplay.swift
//  Cue Studio
//

import Foundation

/// Which captions show (and export): the original lines, a translation, or both, the translation
/// smaller under (or over) the original.
nonisolated enum CaptionDisplay: Codable, Hashable, Sendable {
    case original
    case translation(CueLanguage)
    case bilingual(CueLanguage)

    /// The translation shown, if any.
    var language: CueLanguage? {
        switch self {
        case .original: nil
        case .translation(let language), .bilingual(let language): language
        }
    }
}
