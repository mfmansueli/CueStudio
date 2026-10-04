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
        let defaults: TestDefaults
    }

    private func makeScenario() -> Scenario {
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now })
        let presentation = PresentationService()
        let ideaDraft = IdeaDraftService()
        let starter = ScriptStarter(
            library: library, rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            languages: TestData.languages(defaults: defaults.defaults), presentation: presentation, ideaDraft: ideaDraft
        )
        return Scenario(starter: starter, library: library, presentation: presentation, ideaDraft: ideaDraft, defaults: defaults)
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
}
