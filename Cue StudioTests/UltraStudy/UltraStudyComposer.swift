//
//  UltraStudyComposer.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// The composer's text for a card's idea in the creator's interface language (`IdeaBrief.composerText`, whose "Angle:" and "Open with:"
/// lines follow the language the app runs in): the test host runs in English, and a Brazilian creator's request carries "Ângulo:" and
/// "Abertura:". Read from the app's own translations.
nonisolated enum UltraStudyComposer {
    struct Missing: Error, CustomStringConvertible {
        let language: String
        var description: String { "No \(language) translation of the composer's lines in the app" }
    }

    static func text(of brief: IdeaBrief, in language: CueLanguage) throws -> String {
        let fitted = brief.fitted()
        let table = try strings(for: language)
        var lines = [fitted.subject]
        if !fitted.angle.isEmpty { lines.append(String(format: table.angle, fitted.angle)) }
        if !fitted.openingLine.isEmpty { lines.append(String(format: table.opening, fitted.openingLine)) }
        return String(lines.joined(separator: "\n").prefix(IdeaPromptDraft.maxCharacters))
    }

    private static func strings(for language: CueLanguage) throws -> (angle: String, opening: String) {
        let angleKey = "Angle: %@", openingKey = "Open with: “%@”"
        guard language != .english else { return (angleKey, openingKey) }
        // The String Catalogs' folder ("zh-Hans", not "zh"): the composer says it as the app does in that language.
        let code = language.interfaceLocalization
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else {
            throw Missing(language: code)
        }
        let angle = bundle.localizedString(forKey: angleKey, value: nil, table: nil)
        let opening = bundle.localizedString(forKey: openingKey, value: nil, table: nil)
        guard angle != angleKey, opening != openingKey else { throw Missing(language: code) }
        return (angle, opening)
    }
}
