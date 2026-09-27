//
//  GenerateScriptViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("GenerateScriptViewModel")
struct GenerateScriptViewModelTests {
    private struct Scenario {
        let viewModel: GenerateScriptViewModel
        let writer: FakeScriptWriter
        let library: ScriptLibraryService
        let quota: UsageQuotaService
        let profile: CreatorProfileService
        let defaults: TestDefaults
    }

    private func makeScenario(tier: MembershipTier = .free) -> Scenario {
        let defaults = TestDefaults()
        let writer = FakeScriptWriter()
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now })
        let quota = UsageQuotaService(defaults: defaults.defaults, now: { TestData.now })
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.addPhrase("Hey fam")
        let viewModel = GenerateScriptViewModel(
            writer: writer, library: library, profile: profile, rules: TestData.rulesService(), quota: quota,
            tier: { tier }, toast: ToastService()
        )
        return Scenario(viewModel: viewModel, writer: writer, library: library, quota: quota, profile: profile, defaults: defaults)
    }

    @Test func generatesAScriptAndCountsTheAIUse() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.choose(.list)
        scenario.viewModel.platform = .reels
        let script = await scenario.viewModel.generate()
        #expect(script?.type == .list)
        #expect(script?.platform == .reels)
        #expect(scenario.library.scripts.count == 1)
        #expect(scenario.quota.aiScriptsLeft(for: .free) == 4)
        #expect(scenario.writer.lastRequest?.phrases == ["Hey fam"])
    }

    @Test func seriousFormatsNeverUseCatchphrases() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.choose(.apology)
        _ = await scenario.viewModel.generate()
        #expect(scenario.writer.lastRequest?.phrases == [])
    }

    @Test func exhaustedQuotaOpensThePaywall() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        for _ in 0..<5 { scenario.quota.recordAIScript(tier: .free) }
        scenario.viewModel.choose(.list)
        let script = await scenario.viewModel.generate()
        #expect(script == nil)
        #expect(scenario.viewModel.paywall == .ai)
        #expect(scenario.library.scripts.isEmpty)
    }

    @Test func structuredDraftDoesNotUseTheQuota() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.writer.isLanguageModelAvailable = false
        scenario.viewModel.choose(.review)
        let script = await scenario.viewModel.generate()
        #expect(script != nil)
        #expect(scenario.quota.aiScriptsLeft(for: .free) == 5)
        #expect(scenario.viewModel.modelNote != nil)
    }

    @Test func choosingAFormatResetsTheBriefAndPicksAMatchingTone() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.choose(.ad)
        scenario.viewModel.setValue("Brand", for: ScriptType.ad.briefFields[0])
        scenario.viewModel.choose(.apology)
        #expect(scenario.viewModel.brief.isEmpty)
        #expect(scenario.viewModel.tone == .sincere)
    }
}
