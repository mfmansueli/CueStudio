//
//  ScriptStarterBriefTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// An idea from Find inspiration on its way to a script: the request carries what of its brief the creator's text still says, and the script that
/// arrives is reported as written from it (the strongest sign of what they want), with no screen having to say so.
@MainActor
@Suite("Script starter · Find inspiration")
struct ScriptStarterBriefTests {
    private struct Scenario {
        let starter: ScriptStarter
        let presentation: PresentationService
        let ideaDraft: IdeaDraftService
        let transition: IdeaTransitionService
        let defaults: TestDefaults
    }

    private func makeScenario() -> Scenario {
        let defaults = TestDefaults()
        let presentation = PresentationService()
        let ideaDraft = IdeaDraftService()
        let transition = IdeaTransitionService()
        transition.speed = 0.001
        let starter = ScriptStarter(
            library: ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now }), rules: TestData.rulesService(),
            profile: CreatorProfileService(defaults: defaults.defaults), languages: TestData.languages(defaults: defaults.defaults),
            presentation: presentation, ideaDraft: ideaDraft, transition: transition, sky: SkyMemory(defaults: defaults.defaults),
            writer: FakeScriptWriter(), toast: ToastService()
        )
        return Scenario(starter: starter, presentation: presentation, ideaDraft: ideaDraft, transition: transition, defaults: defaults)
    }

    private var idea: ThemeIdea {
        var idea = ThemeIdea(title: "Why saving feels harder than spending", kind: "Explainer", length: .minute1, niche: .finance)
        idea.brief = IdeaBrief(
            subject: idea.title, angle: "Explain one small habit that makes saving easier.",
            openingLine: "Saving isn’t just about willpower.", angleKind: "fact", topicKey: "finance"
        )
        return idea
    }

    @Test func theFieldsBriefGoesWithTheRequestAndTheScriptIsReportedWhenItArrives() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        var reported: [IdeaBrief] = []
        scenario.starter.briefWritten = { reported.append($0) }
        scenario.ideaDraft.use(idea)
        #expect(scenario.ideaDraft.submittedBrief == idea.brief)
        scenario.starter.write(from: .zero)
        #expect(scenario.presentation.scriptsPath.first?.writing?.brief == idea.brief)
        #expect(reported.isEmpty, "not before it is written")
        await scenario.transition.contentReady()
        #expect(reported == [idea.brief!])
    }

    @Test func anAngleTheCreatorRewroteIsNotSent() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.use(idea)
        scenario.ideaDraft.text = "Why saving feels harder than spending\nAngle: compare three apps that round up purchases"
        scenario.starter.write(from: .zero)
        let sent = scenario.presentation.scriptsPath.first?.writing?.brief
        #expect(sent?.subject == idea.title && sent?.angle == "" && sent?.openingLine == "")
    }

    @Test func theRoulettesDirectWriteSendsTheBriefWithItsText() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        var reported = 0
        scenario.starter.briefWritten = { _ in reported += 1 }
        scenario.starter.write(idea: idea.brief!.composerText, brief: idea.brief, from: .zero)
        #expect(scenario.presentation.scriptsPath.first?.writing?.brief == idea.brief)
        await scenario.transition.contentReady()
        #expect(reported == 1)
    }

    @Test func aTypedIdeaHasNoBriefAndReportsNothing() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        var reported = 0
        scenario.starter.briefWritten = { _ in reported += 1 }
        scenario.ideaDraft.text = "My trip to Lisbon"
        scenario.starter.write(from: .zero)
        #expect(scenario.presentation.scriptsPath.first?.writing?.brief == nil)
        await scenario.transition.contentReady()
        #expect(reported == 0)
    }

    // MARK: - The field

    @Test func useThisIdeaKeepsWhatTheCreatorWroteForUndo() {
        let draft = IdeaDraftService()
        draft.text = "My own half idea"
        draft.platform = .reels
        draft.use(idea)
        #expect(draft.text == idea.brief?.composerText)
        #expect(draft.platform == .reels, "the card's choices stay")
        #expect(draft.canUndoUse)
        draft.undoUse()
        #expect(draft.text == "My own half idea" && draft.brief == nil && !draft.canUndoUse)
    }

    @Test func useThisIdeaOnAnEmptyFieldOrOverAnotherIdeaHasNothingToUndo() {
        let draft = IdeaDraftService()
        draft.use(idea)
        #expect(!draft.canUndoUse)
        var other = idea
        other.title = "Another"
        other.brief?.subject = "Another"
        draft.use(other)
        #expect(!draft.canUndoUse, "an idea of Cue's replaced by another is not the creator's text")
        draft.clear()
        #expect(draft.brief == nil && draft.text.isEmpty)
    }
}
