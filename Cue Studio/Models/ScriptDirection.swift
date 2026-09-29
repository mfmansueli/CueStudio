//
//  ScriptDirection.swift
//  Cue Studio
//

import Foundation

/// Which way a script reads, from its language, whatever the interface's is: an Arabic script aligns
/// right in an English interface, and an English script aligns left in an Arabic one.
nonisolated enum ScriptDirection {
    static func isRightToLeft(language: CueLanguage?, text: String) -> Bool {
        if let language { return language.isRightToLeft }
        guard let code = LanguageDetector.dominantLanguageCode(in: text) else { return false }
        return Locale.Language(identifier: code).characterDirection == .rightToLeft
    }
}
