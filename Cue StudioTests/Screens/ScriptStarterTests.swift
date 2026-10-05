//
//  ScriptStarterTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// An idea sent to the script page: a new empty script and a request waiting on it.
@MainActor
@Suite("Script starter")
struct ScriptStarterTests {
    private struct Scenario {
        let starter: ScriptStarter
        let library: ScriptLibraryService
        let presentation: PresentationService
        let ideaDraft: IdeaDraftService
        let transition: IdeaTransitionService
        let sky: SkyMemory
        let writer: FakeScriptWriter
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario(languages: LanguageService? = nil) -> Scenario {
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now })
        let presentation = PresentationService()
        let ideaDraft = IdeaDraftService()
        let transition = IdeaTransitionService()
        transition.speed = 0.01
        let sky = SkyMemory(defaults: defaults.defaults)
        let writer = FakeScriptWriter()
        let toast = ToastService()
        let starter = ScriptStarter(
            library: library, rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            languages: languages ?? TestData.languages(defaults: defaults.defaults), presentation: presentation, ideaDraft: ideaDraft,
            transition: transition, sky: sky, writer: writer, toast: toast
        )
        return Scenario(
            starter: starter, library: library, presentation: presentation, ideaDraft: ideaDraft, transition: transition, sky: sky,
            writer: writer, toast: toast, defaults: defaults
        )
    }

    @Test func theCardsIdeaOpensANewScriptWithItsRequest() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "  Carnival in Salvador "
        scenario.ideaDraft.platform = .reels
        scenario.ideaDraft.format = .review
        scenario.starter.write()
        #expect(scenario.library.scripts.count == 1)
        let script = scenario.library.scripts[0]
        #expect(script.isEmpty && script.platform == .reels && script.type == .review)
        let route = scenario.presentation.scriptsPath.first
        #expect(route?.scriptID == script.id && route?.startsEditing == true)
        #expect(route?.writing?.source == .prompt("Carnival in Salvador"))
        #expect(route?.writing?.format == .review)
        // The card keeps its idea until the script is written (a failed request can be tried again).
        #expect(scenario.ideaDraft.text == "  Carnival in Salvador ")
    }

    @Test func anIdeaFromTheIdeasSheetIsWrittenAsIs() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.starter.write(idea: "1 min list video: 3 things I stopped buying", length: .minute1)
        #expect(scenario.presentation.scriptsPath.first?.writing?.targetRange == 54...66)
    }

    @Test func nothingIsWrittenFromAnEmptyIdea() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "   "
        scenario.starter.write()
        #expect(scenario.library.scripts.isEmpty && scenario.presentation.scriptsPath.isEmpty)
    }

    @Test func theCardsPlatformIsTheChoiceOrTheDefault() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.starter.platform == .tiktok)
        scenario.ideaDraft.platform = .linkedin
        #expect(scenario.starter.platform == .linkedin)
    }

    @Test func theIdeasStarRisesAsTheTransitionAndCancelTakesTheScriptBack() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.starter.write(from: CGPoint(x: 300, y: 700))
        #expect(scenario.transition.isActive && scenario.transition.idea == "Carnival in Salvador")
        #expect(scenario.library.scripts.count == 1 && !scenario.presentation.scriptsPath.isEmpty)
        scenario.transition.cancel()
        // No script is created, the page goes, and the idea is still in the field.
        #expect(scenario.library.scripts.isEmpty && scenario.presentation.scriptsPath.isEmpty)
        #expect(scenario.ideaDraft.text == "Carnival in Salvador")
        #expect(scenario.sky.points.isEmpty)
    }

    @Test func whenTheScriptIsReadyTheIdeaBecomesAStarInTheSky() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.starter.write(from: CGPoint(x: 300, y: 700))
        await scenario.transition.contentReady()
        #expect(scenario.sky.points.count == 1)
        #expect(scenario.library.scripts.count == 1)
    }

    // MARK: - A language Apple Intelligence doesn't write

    /// The star flies for three seconds only to fall: a language the model can't write is told at once, and the
    /// idea becomes a blank draft to write by hand, the way it does without Apple Intelligence.
    @Test func anIdeaInALanguageTheModelCannotWriteOpensABlankDraftWithTheReason() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.writer.writingFailureToReturn = .unsupportedLanguage(Locale.Language(identifier: "th"))
        scenario.ideaDraft.text = "ทำไมฉันเลิกกินกาแฟสามสิบวันแล้วชีวิตเปลี่ยนไป"
        let id = scenario.starter.write()
        #expect(id != nil)
        #expect(scenario.library.scripts.count == 1)
        let route = scenario.presentation.scriptsPath.first
        #expect(route?.writing == nil)
        #expect(route?.startsEditing == true)
        #expect(scenario.toast.message == ScriptAIError.unsupportedLanguage.localizedDescription)
        #expect(!scenario.transition.isActive)
    }

    @Test func aSupportedLanguageStillGoesToTheModel() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.starter.write()
        #expect(scenario.presentation.scriptsPath.first?.writing != nil)
        #expect(scenario.toast.message == nil)
    }
}
