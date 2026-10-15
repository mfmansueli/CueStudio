//
//  LanguageSweepCasesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The 20-language sweep (`LanguageSweepCases`) is only run on a device, and a language it forgot would go unnoticed there: these checks run with
/// the unit tests.
@Suite("Language sweep cases")
struct LanguageSweepCasesTests {
    @Test func coversEveryLanguageOnce() {
        let languages = LanguageSweepCases.all.map(\.language)
        #expect(Set(languages) == Set(CueLanguage.allCases))
        #expect(languages.count == CueLanguage.allCases.count)
    }

    @Test(arguments: LanguageSweepCases.all)
    func hasAnIdeaAndABriefThatFits(_ item: LanguageSweepCase) {
        #expect(!item.idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(item.idea.count <= IdeaPromptDraft.maxCharacters)
        #expect(item.brief.composerText.count <= IdeaPromptDraft.maxCharacters)
        // Nothing of it is cut on the way to the composer, so the model reads the whole brief.
        #expect(item.brief.fitted() == item.brief)
    }
}
