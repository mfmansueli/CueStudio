//
//  OnboardingScriptTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The first script: a hook, a body and a call to action.
@Suite("OnboardingScript")
struct OnboardingScriptTests {
    @Test func threeParagraphsAreTheHookTheBodyAndTheCallToAction() {
        let script = OnboardingScript.parsing(title: "T", text: "Okay, real talk.\n\nNo phone for twenty minutes.\n\nTry it tomorrow.")
        #expect(script.hook == "Okay, real talk.")
        #expect(script.body == "No phone for twenty minutes.")
        #expect(script.cta == "Try it tomorrow.")
        #expect(!script.isCurated)
    }

    @Test func moreParagraphsFoldTheMiddleIntoTheBody() {
        let script = OnboardingScript.parsing(title: "T", text: "One.\n\nTwo.\n\nThree.\n\nFour.")
        #expect(script.hook == "One." && script.cta == "Four.")
        #expect(script.body == "Two. Three.")
    }

    @Test func oneParagraphIsSplitIntoSentences() {
        let script = OnboardingScript.parsing(title: "T", text: "Hello there. This is the middle. And this is the end.")
        #expect(script.hook == "Hello there.")
        #expect(script.body == "This is the middle.")
        #expect(script.cta == "And this is the end.")
    }

    @Test func aVeryShortTextStillMakesAScript() {
        let script = OnboardingScript.parsing(title: "T", text: "Just one line")
        #expect(script.hook == "Just one line")
        #expect(script.text == "Just one line")
    }

    @Test func theTextJoinsThePartsWithBlankLines() {
        let script = OnboardingScript(title: "T", hook: "A.", body: "B.", cta: "C.", isCurated: false)
        #expect(script.text == "A.\n\nB.\n\nC.")
        #expect(OnboardingScript(title: "T", hook: "A.", body: "", cta: "C.", isCurated: false).text == "A.\n\nC.")
    }

    @Test func ourOwnScriptIsLabelledAndNamesTheTopic() {
        let script = OnboardingScript.curated(topic: "Budget travel")
        #expect(script.isCurated)
        #expect(script.hook.contains("Budget travel"))
        #expect(!script.body.isEmpty && !script.cta.isEmpty)
    }
}
