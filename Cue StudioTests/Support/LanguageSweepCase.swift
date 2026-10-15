//
//  LanguageSweepCase.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the 20-language sweep of the script-quality measurement writes in one language (`ScriptQualityDeviceTests.sweepsEveryLanguage`): a free
/// idea a creator would type, one that promises a number of things, and a Find inspiration brief, both as a native creator would write them in
/// that language and its own writing system. Invented, never any real creator's.
nonisolated struct LanguageSweepCase: Sendable, CustomTestStringConvertible {
    let language: CueLanguage
    let idea: String
    let brief: IdeaBrief

    var testDescription: String { language.rawValue }

    /// The brief is tagged the way Find inspiration tags its own: the language by its minimal identifier ("en", "zh-TW"), the angle and the topic
    /// by their raw values, so the script is asked for exactly as a starter's would be.
    init(language: CueLanguage, idea: String, subject: String, angle: String, openingLine: String, angleKind: IdeaAngle, topic: Niche) {
        self.language = language
        self.idea = idea
        brief = IdeaBrief(
            subject: subject, angle: angle, openingLine: openingLine, language: language.locale.language.minimalIdentifier,
            angleKind: angleKind.rawValue, topicKey: topic.rawValue
        )
    }
}
