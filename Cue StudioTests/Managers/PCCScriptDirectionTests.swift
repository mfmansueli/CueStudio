//
//  PCCScriptDirectionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("PCC script direction and input fidelity")
struct PCCScriptDirectionTests {
    private func request() -> ScriptRequest {
        ScriptRequest(
            source: .prompt("Explique três passos para iniciantes, cite o projeto Aurora 27 e termine sem pedir para seguir."),
            platform: .youtube, tone: nil, voice: QualityProfiles.english.full.voice(inLanguage: "pt"),
            targetRange: 120...180, language: .portugueseBrazil
        )
    }

    @Test func currentRequestArrivesIntactOnceAlongsideRelevantVoiceAndOutputChoices() {
        let original = request()
        let cloud = AIRequestPolicy.prepare(original, on: .privateCloud)
        let instructions = ScriptPromptBuilder.instructions(for: cloud)
        let prompt = ScriptPromptBuilder.prompt(for: cloud)
        guard case .prompt(let typed) = original.source else { return }
        #expect(prompt.components(separatedBy: typed).count == 2, "the complete request is supplied once, without a lossy summary")
        #expect(instructions.contains("Portuguese"))
        #expect(prompt.contains(cloud.platform.promptName))
        #expect(prompt.contains("between 405 and 473 spoken words"))
        #expect(instructions.contains("usual topics, openings, endings and style are defaults"))
        #expect(instructions.contains("including no call to action"))
        #expect(prompt.hasSuffix(PCCScriptDirection.finalCheck), "literal requirements are checked after voice/style defaults")
        #expect(!instructions.contains("Here is how they write"), "PCC does not receive local writing examples")
    }

    @Test func cloudDraftProvidesMaterialNearNinetySecondsAtNaturalReadingPace() {
        let range = ScriptPromptBuilder.askedRange(for: 60...90, on: .privateCloud)
        #expect(range.low == 203)
        #expect(range.high == 237)
        let rule = ScriptPromptBuilder.lengthRule(minimumWords: range.low, on: .privateCloud)
        #expect(rule.contains("explicit word or time limit"))
        #expect(rule.contains("Never stretch the duration"))
        #expect(ScriptPromptBuilder.askedRange(for: 60...90).low == 150)
    }

    @Test func cloudVoiceDefaultsDoNotForceStoriesCatchphrasesOrEngagement() {
        let original = request()
        let cloud = AIRequestPolicy.prepare(original, on: .privateCloud)
        let instructions = ScriptPromptBuilder.instructions(for: cloud)
        #expect(instructions.contains("Usual opening preference"))
        #expect(instructions.contains("Usual ending preference"))
        #expect(instructions.contains("Optional familiar expressions"))
        #expect(!instructions.contains("\nOpen with "))
        #expect(!instructions.contains("\nEnd by "))
        #expect(!instructions.contains("Use one once after the first sentence"))
        #expect(instructions.contains("observable action and why it helps"))
        #expect(instructions.contains("unrelated video"))
        let local = ScriptPromptBuilder.instructions(for: AIRequestPolicy.prepare(original, on: .onDevice))
        #expect(local.contains("\nOpen with "))
        #expect(local.contains("\nEnd by "))
    }

    @Test(arguments: Platform.allCases)
    func cloudPlatformConventionsNeverForceAnEngagementEnding(_ platform: Platform) {
        var original = request()
        original.platform = platform
        let instructions = ScriptPromptBuilder.instructions(for: AIRequestPolicy.prepare(original, on: .privateCloud))
        #expect(instructions.contains("Platform conventions never require an engagement CTA"))
        #expect(!instructions.contains("an ending that asks to save or share"))
        #expect(!instructions.contains("close by pointing to the next video"))
    }

    @Test func anIncompleteCloudBriefNeverTurnsFormExamplesIntoTheCreatorsFacts() {
        var original = request()
        original.source = .format(.story, brief: ["setup": "The Aurora 27 meeting ended at 14:35!", "twist": "  "])
        let cloud = AIRequestPolicy.prepare(original, on: .privateCloud)
        let prompt = ScriptPromptBuilder.prompt(for: cloud)
        #expect(prompt.contains("The Aurora 27 meeting ended at 14:35!"), "names, quantities and punctuation survive")
        for field in ScriptType.story.briefFields {
            #expect(!prompt.contains(field.example), "a missing answer must not become a fictional contract or testimonial")
        }
        #expect(prompt.contains("missing answers"))
    }

    @Test func seriousStatementsDoNotAcquireAnEntertainmentOrEngagementChecklist() {
        var original = request()
        original.format = .apology
        let cloud = AIRequestPolicy.prepare(original, on: .privateCloud)
        let direction = PCCScriptDirection.instructions(for: cloud).joined(separator: "\n")
        #expect(direction.contains("Never invent an incident, excuse, remedy or commitment"))
        #expect(!direction.contains("fresh, relevant angle"))
        #expect(!direction.contains("invitation"))
    }

    @Test func brandLimitsAndExactApprovedDetailsRemainAlongsideEditorialDirection() {
        var original = request()
        original.format = .ad
        original.brand = BrandBrief(
            name: "Aurora 27", product: "Desk light", mustSay: "Three brightness settings",
            neverSay: "medical benefits", link: "https://example.com/aurora", code: "LIGHT27"
        )
        let cloud = AIRequestPolicy.prepare(original, on: .privateCloud)
        let prompt = ScriptPromptBuilder.prompt(for: cloud)
        for detail in ["Aurora 27", "Desk light", "Three brightness settings", "medical benefits", "https://example.com/aurora", "LIGHT27", "#ad"] {
            #expect(prompt.contains(detail))
        }
        #expect(PCCScriptDirection.instructions(for: cloud).joined().contains("Do not add a benefit, comparison or urgency"))
    }

    @Test func localGenerationRetainsItsMeasuredPromptBudget() {
        let local = AIRequestPolicy.prepare(request(), on: .onDevice)
        #expect(PCCScriptDirection.instructions(for: local).isEmpty)
        #expect(!ScriptPromptBuilder.instructions(for: local).contains("Before returning only"))
    }

    @Test(arguments: [
        "Me ensine a iluminar o rosto usando uma janela, sem CTA.",
        "Compare two ways to plan a filming day without inventing a personal test.",
        "Responde a este comentario con dos razones y una pregunta.",
        "Raconte une histoire à partir de cette expérience : mon micro était coupé.",
        "初心者向けに動画の照明を説明してください。",
    ])
    func automaticLetsPCCReadIntentInsteadOfLockingItToAnEnglishKeywordGuess(_ idea: String) {
        var original = request()
        original.source = .prompt(idea)
        original.voice?.formats = [.list]
        let cloud = AIRequestPolicy.prepare(original, on: .privateCloud)
        let prompt = ScriptPromptBuilder.prompt(for: cloud)
        #expect(prompt.contains(idea))
        #expect(prompt.contains("Format is Automatic"))
        #expect(!prompt.contains("Write a list of tips script"), "the usual format cannot decide before the model reads the request")
        #expect(!prompt.contains("Blocks, in this order:"), "Auto chooses an appropriate structure in the same generation call")
        #expect(cloud.format == nil && original.format == nil, "no inferred format is silently saved as a manual choice")
    }

    @Test func aManualFormatStillDeterminesTheStructureOnPCC() {
        var original = request()
        original.format = .story
        let cloud = AIRequestPolicy.prepare(original, on: .privateCloud)
        let prompt = ScriptPromptBuilder.prompt(for: cloud)
        #expect(prompt.contains("Write a storytime script"))
        #expect(prompt.contains("Blocks, in this order: Hook → Setup → Twist → Payoff"))
        #expect(!prompt.contains("Format is Automatic"))
    }

    @Test @MainActor func talkingHeadRemainsAnExplicitChoiceFromTheDockThroughThePrompt() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            scriptLanguage: .english, interfaceLanguage: .english
        )
        let original = factory.request(idea: "How to start running", platform: nil, format: nil, formatChoice: .talkingHead)
        for route in [AIModelRoute.onDevice, .privateCloud] {
            let prepared = AIRequestPolicy.prepare(original, on: route)
            #expect(prepared.formatChoice == .talkingHead)
            #expect(!PCCScriptDirection.usesAutomaticFormat(prepared))
            #expect(ScriptPromptBuilder.prompt(for: prepared).contains("Write a talking head script"))
        }
    }
}
