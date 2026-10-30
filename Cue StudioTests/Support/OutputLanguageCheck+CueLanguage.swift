//
//  OutputLanguageCheck+CueLanguage.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

extension OutputLanguageCheck {
    /// Whether `text` reads as `expected`, one of Cue's languages (the app asks with the request's `Locale.Language`).
    static func isPlausible(_ text: String, in expected: CueLanguage) -> Bool {
        isPlausible(text, in: expected.locale.language)
    }
}
