//
//  ScriptShapeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A script read as sections, for the teleprompter's markers.
@Suite("Script shape")
struct ScriptShapeTests {
    private func shape(_ text: String, structure: ScriptStructure = .generic) -> ScriptShape {
        ScriptShape(text: text, structure: structure)
    }

    @Test func aTalkingVideoHasHookBodyAndCTAWhenItClosesOnACallToAction() {
        let result = shape("Okay, real talk.\n\nFirst point.\n\nSecond point.\n\nFollow for part two.")
        #expect(result.sections.map(\.label) == ["Hook", "Body", "CTA"])
        #expect(result.sections[1].paragraphs.count == 2)
        #expect(result.sections.allSatisfy { !$0.isMissingCTA })
        #expect(result.sections[0].isHook && !result.sections[1].isHook)
    }

    @Test func aScriptThatDoesntCloseOnACallToActionSaysSo() {
        let result = shape("Okay, real talk.\n\nFirst point.\n\nSecond point.")
        // The last paragraph is body, and an empty CTA is offered.
        #expect(result.sections.map(\.label) == ["Hook", "Body", "CTA"])
        #expect(result.sections[1].paragraphs.count == 2)
        #expect(result.sections[2].isMissingCTA && result.sections[2].paragraphs.isEmpty)
    }

    @Test func anEmptyScriptHasNoSectionsAndNothingMissing() {
        #expect(shape("").sections.isEmpty)
        #expect(shape("  \n ").sections.isEmpty)
    }

    @Test func aSeriousFormatHasNoHook() {
        let structure = ScriptType.apology.structure
        let result = shape(TestData.words(40) + ".\n\nWe own it.\n\nThis is what changes.", structure: structure)
        #expect(result.sections.allSatisfy { !$0.isHook })
    }
}
