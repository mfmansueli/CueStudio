//
//  ScriptPageUltraTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The script page writing an Ultra AI request: Ultra writes it and Apple Intelligence is never asked, the script is saved once with Ultra's
/// provenance and the fact-check reminder, and a failure says what happened without leaving a half-written script behind.
@MainActor
@Suite("Script page · Ultra AI")
struct ScriptPageUltraTests {
    private struct Scenario {
        let viewModel: ScriptDetailViewModel
        let library: ScriptLibraryService
        let writer: FakeScriptWriter
        let ultra: FakeUltraScriptWriter
        let defaults: TestDefaults
    }

    private func makeScenario(ultra: FakeUltraScriptWriter? = FakeUltraScriptWriter()) -> Scenario {
        let defaults = TestDefaults()
        let script = TestData.script(title: "", text: "")
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]), now: { TestData.now })
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: []))
        takes.load()
        let writer = FakeScriptWriter()
        var request = ScriptRequest(source: .prompt("Carnival in Salvador"), platform: .reels, tone: nil, voice: nil, targetRange: 30...60)
        request.engine = .ultra
        let viewModel = ScriptDetailViewModel(
            scriptID: script.id, startsEditing: false, writing: request, ideaDraft: IdeaDraftService(), revealPause: .zero,
            library: library, takes: takes, preferences: PreferencesService(defaults: defaults.defaults),
            profile: CreatorProfileService(defaults: defaults.defaults), rules: TestData.rulesService(), writer: writer, ultra: ultra,
            toast: ToastService()
        )
        return Scenario(viewModel: viewModel, library: library, writer: writer, ultra: ultra ?? FakeUltraScriptWriter(), defaults: defaults)
    }

    @Test func ultraWritesItAndAppleIntelligenceIsNeverAsked() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.beginWritingIfNeeded()
        await scenario.viewModel.pageWritingTask?.value
        #expect(scenario.ultra.requests.count == 1 && scenario.writer.lastRequest == nil)
        let saved = scenario.library.script(id: scenario.viewModel.scriptID)
        #expect(saved?.text == "The polished Ultra script.")
        #expect(saved?.draftedBy == .ultra && saved?.factCheck == true)
        #expect(scenario.viewModel.needsFactCheck)
    }

    @Test func aFailedUltraScriptSaysSoAndLeavesNothingHalfWritten() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ultra.error = UltraError.reviewFailed(.provider, draft: "A draft that must never be shown as the script.")
        scenario.viewModel.beginWritingIfNeeded()
        await scenario.viewModel.pageWritingTask?.value
        #expect(scenario.viewModel.page.writingError == UltraError.reviewFailed(.provider, draft: "").localizedDescription)
        let saved = scenario.library.script(id: scenario.viewModel.scriptID)
        #expect(saved?.text.isEmpty == true && saved?.draftedBy == nil)
        #expect(scenario.writer.lastRequest == nil)
    }

    @Test func withoutUltraOnThePageNothingFallsBackToAppleIntelligence() async {
        let scenario = makeScenario(ultra: nil)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.beginWritingIfNeeded()
        await scenario.viewModel.pageWritingTask?.value
        #expect(scenario.writer.lastRequest == nil)
        #expect(scenario.viewModel.page.writingError == UltraError.notAvailable.localizedDescription)
    }

    @Test func anOlderLibraryReadsWithoutProvenance() throws {
        let script = TestData.script(title: "Old", text: "Old text.")
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(script)) as? [String: Any])
        object["draftedBy"] = nil
        #expect(try JSONDecoder().decode(Script.self, from: JSONSerialization.data(withJSONObject: object)).draftedBy == nil)
        object["draftedBy"] = "someFutureEngine"
        #expect(try JSONDecoder().decode(Script.self, from: JSONSerialization.data(withJSONObject: object)).draftedBy == nil)
        object["draftedBy"] = "ultra"
        #expect(try JSONDecoder().decode(Script.self, from: JSONSerialization.data(withJSONObject: object)).draftedBy == .ultra)
    }
}
