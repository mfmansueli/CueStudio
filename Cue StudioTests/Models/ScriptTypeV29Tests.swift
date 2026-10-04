//
//  ScriptTypeV29Tests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// L3: Myth vs fact and POV join the 8 formats (11 tiles with Auto and Talking head); no format is lost.
@Suite("ScriptType · v29")
struct ScriptTypeV29Tests {
    @Test func theTenFormatsKeepTheirRawValues() {
        #expect(ScriptType.allCases.map(\.rawValue) == ["ad", "review", "tutorial", "list", "story", "opinion", "launch", "apology", "mythFact", "pov"])
    }

    @Test func mythVsFactHasTheBoardsSections() {
        #expect(ScriptType.mythFact.structure.blocks.count == 4)
        #expect(ScriptType.mythFact.structure.blocks.first == "Myth")
        #expect(!ScriptType.mythFact.structure.isSerious)
    }

    @Test func povHasThreeSections() {
        #expect(ScriptType.pov.structure.blocks == ["POV line", "Scene", "Twist"])
    }

    @Test(arguments: [ScriptType.mythFact, .pov])
    func aNewFormatBuildsAnOfflineDraftWithOneParagraphPerStep(type: ScriptType) {
        let draft = type.draft(from: [:])
        #expect(!draft.isEmpty)
        #expect(!type.draftTitle(from: [:]).isEmpty)
        #expect(!type.briefFields.isEmpty)
        #expect(type.structure.hooks.count == 4)
        #expect(draft.components(separatedBy: "\n\n").count >= 3)
    }

    @Test func aFormatSavedByThisBuildDecodesAndOneFromANewerBuildDoesNot() throws {
        #expect(try JSONDecoder().decode(ScriptType.self, from: Data(#""mythFact""#.utf8)) == .mythFact)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ScriptType.self, from: Data(#""holographic""#.utf8)) }
    }
}
