//
//  ScriptStarterUltraTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Ultra AI from the dock and from Find inspiration: only when it was picked and allowed (never a silent stand-in for Apple Intelligence), without
/// Apple Intelligence's language check, with the inspiration's brief, and back on Apple Intelligence once the script is written.
@MainActor
@Suite("Script starter · Ultra AI")
struct ScriptStarterUltraTests {
    private struct Scenario {
        let starter: ScriptStarter
        let library: ScriptLibraryService
        let presentation: PresentationService
        let ideaDraft: IdeaDraftService
        let transition: IdeaTransitionService
        let writer: FakeScriptWriter
        let ultra: FakeUltraScriptWriter
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario(ultraReady: Bool = true) -> Scenario {
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now })
        let presentation = PresentationService()
        let ideaDraft = IdeaDraftService()
        let transition = IdeaTransitionService()
        transition.speed = 0.001
        let writer = FakeScriptWriter()
        let ultra = FakeUltraScriptWriter()
        ultra.isReady = ultraReady
        let toast = ToastService()
        let starter = ScriptStarter(
            library: library, profile: CreatorProfileService(defaults: defaults.defaults),
            languages: TestData.languages(defaults: defaults.defaults), presentation: presentation, ideaDraft: ideaDraft,
            transition: transition, writer: writer, ultra: ultra, toast: toast
        )
        return Scenario(
            starter: starter, library: library, presentation: presentation, ideaDraft: ideaDraft, transition: transition, writer: writer,
            ultra: ultra, toast: toast, defaults: defaults
        )
    }

    @Test func ultraIsOfferedOnlyWhereItIs() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.starter.offersUltra)
        scenario.ultra.isAvailable = false
        #expect(!scenario.starter.offersUltra)
        let plain = ScriptStarter(
            library: scenario.library, profile: CreatorProfileService(defaults: scenario.defaults.defaults),
            languages: TestData.languages(defaults: scenario.defaults.defaults), presentation: scenario.presentation,
            ideaDraft: scenario.ideaDraft, transition: scenario.transition, writer: scenario.writer, toast: scenario.toast
        )
        #expect(!plain.offersUltra)
    }

    @Test func pickingUltraBeforeAllowingItStaysOnAppleIntelligence() {
        let scenario = makeScenario(ultraReady: false)
        defer { scenario.defaults.tearDown() }
        scenario.starter.choose(.ultra)
        #expect(scenario.ideaDraft.engine == .apple && !scenario.starter.writesWithUltra)
    }

    @Test func theDocksUltraIdeaGoesToUltraWithoutAppleIntelligencesLanguageCheck() throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.writer.languagesNotWritten = ["th"]
        scenario.writer.writingFailureToReturn = .deviceNotSupported
        scenario.starter.choose(.ultra)
        #expect(scenario.starter.dockDrafting.isAvailable)
        scenario.ideaDraft.text = "ทำไมฉันเลิกกินกาแฟสามสิบวันแล้วชีวิตเปลี่ยนไป"
        _ = try #require(scenario.starter.write())
        #expect(scenario.presentation.scriptsPath.first?.writing?.engine == .ultra)
        #expect(scenario.transition.engine == .ultra)
    }

    @Test func revokedBeforeSendingNothingIsWrittenByEither() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.starter.choose(.ultra)
        scenario.ultra.isReady = false
        scenario.ideaDraft.text = "Carnival in Salvador"
        #expect(scenario.starter.write() == nil)
        #expect(scenario.library.scripts.isEmpty && scenario.presentation.scriptsPath.isEmpty)
        #expect(scenario.toast.message == UltraError.consentRequired.localizedDescription)
        #expect(scenario.ideaDraft.engine == .apple)
    }

    @Test func findInspirationsUltraKeepsTheBriefAndTheDocksChoice() throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let brief = IdeaBrief(
            subject: "Why saving feels harder than spending", angle: "Explain one small habit that makes saving easier.",
            openingLine: "Saving isn’t just about willpower.", angleKind: "fact", topicKey: "finance"
        )
        // As Find inspiration sends it: the idea with its angle and opening line (`FindInspirationViewModel.writingText`).
        _ = try #require(scenario.starter.write(idea: brief.composerText, brief: brief, engine: .ultra))
        let request = try #require(scenario.presentation.scriptsPath.first?.writing)
        #expect(request.engine == .ultra && request.brief?.angle == brief.angle)
        #expect(scenario.ideaDraft.engine == .apple)
    }

    @Test func draftItNowStaysWithAppleIntelligenceWhateverTheDockPicked() throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.starter.choose(.ultra)
        _ = try #require(scenario.starter.write(idea: "Why saving feels harder than spending", engine: .apple))
        #expect(scenario.presentation.scriptsPath.first?.writing?.engine == .apple)
    }

    @Test func theWritersPickStaysForTheNextIdea() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.starter.choose(.ultra)
        scenario.ideaDraft.text = "Carnival in Salvador"
        _ = try #require(scenario.starter.write(from: CGPoint(x: 300, y: 700)))
        await scenario.transition.contentReady()
        #expect(scenario.ideaDraft.engine == .ultra && scenario.starter.writesWithUltra)
    }

    @Test func theWritersPickIsKeptBetweenLaunches() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        #expect(IdeaDraftService(defaults: defaults.defaults).engine == .apple, "Apple Intelligence until the creator picks")
        IdeaDraftService(defaults: defaults.defaults).engine = .ultra
        #expect(IdeaDraftService(defaults: defaults.defaults).engine == .ultra)
        let draft = IdeaDraftService(defaults: defaults.defaults)
        draft.engine = .apple
        draft.clear()
        #expect(IdeaDraftService(defaults: defaults.defaults).engine == .apple)
    }

    @Test func withNoFreeScriptsLeftCueProIsOfferedAndNothingIsWritten() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ultra.scriptsLeft = 0
        scenario.ultra.membership = .free
        scenario.ideaDraft.text = "Carnival in Salvador"
        #expect(scenario.starter.write(engine: .ultra) == nil)
        #expect(scenario.library.scripts.isEmpty && scenario.presentation.scriptsPath.isEmpty)
        #expect(scenario.presentation.paywall == .ultra && scenario.ideaDraft.engine == .apple)
    }

    @Test func onProTheToastSaysWhenMoreCome() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ultra.scriptsLeft = 0
        scenario.ultra.membership = .paid
        scenario.starter.choose(.ultra)
        #expect(scenario.ideaDraft.engine == .apple)
        scenario.starter.showUltraUsedUp()
        #expect(scenario.presentation.paywall == nil)
        #expect(scenario.toast.message == "This month’s Ultra AI scripts are used · More next month")
    }

    @Test func anAppleIntelligenceScriptCountsTowardsTheInvitation() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        _ = try #require(scenario.starter.write(from: CGPoint(x: 300, y: 700)))
        await scenario.transition.contentReady()
        #expect(scenario.ultra.aiUses == 1)
    }

    @Test func theDisclosureShowsTheDocksIdeaOrAPlaceholder() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.starter.ultraPreview().draft.prompt.contains(String(localized: "[Your idea, exactly as you type it]")))
        scenario.ideaDraft.text = "Carnival in Salvador"
        #expect(scenario.starter.ultraPreview().draft.prompt.contains("\"\"\"\nCarnival in Salvador\n\"\"\""))
    }
}
