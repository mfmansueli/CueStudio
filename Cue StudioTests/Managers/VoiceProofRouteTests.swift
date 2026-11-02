//
//  VoiceProofRouteTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The owner's D1 and item 3 (02/11/2026): the proof (pasted examples, imported writing, approved scripts) reaches Apple Intelligence on this
/// iPhone and in Private Cloud Compute the same way, inside the cloud's voice budget, and never Ultra AI; the meter is "What Cue knows", one
/// number for both routes; and every text says so. The Private Cloud Compute prompts of the three quality creators are kept in
/// `Fixtures/VoiceBriefs/pcc` with their sizes, before and after the proof (record again with `TEST_RUNNER_CUE_RECORD_SNAPSHOTS=1`).
@MainActor
@Suite("My Cue Voice · the proof on each route")
struct VoiceProofRouteTests {
    private static let pasted = "PROOF-PASTED-SENTENCE"
    private static let imported = "PROOF-IMPORTED-SENTENCE"
    private static let approved = "PROOF-APPROVED-SENTENCE"
    private static let markers = [pasted, imported, approved]
    /// `VoiceBriefBuilder`'s line over the examples.
    private static let header = "Here is how they write"

    private func voice() -> CreatorVoice {
        var voice = QualityProfiles.english.full.voice(inLanguage: "en")
        voice.examples = [VoiceExample(text: "\(Self.pasted): okay, real talk, you don't need a gym, you need a plan you repeat.")]
        voice.excerpts = [VoiceExcerpt(text: "\(Self.imported): twenty minutes, a mat and two dumbbells. That's the whole kit.", language: "en")]
        voice.approvedSamples = [VoiceExample(text: "\(Self.approved): push your hips back and go slow.", source: "Sounds like me")]
        return voice
    }

    private func request(_ voice: CreatorVoice? = nil) -> ScriptRequest {
        ScriptRequest(source: .prompt("Three mistakes on leg day"), platform: .tiktok, voice: voice ?? self.voice(), targetRange: 60...90,
                      language: .english)
    }

    /// The request a creator's card sends, built by the factory the app uses, in the creator's language.
    private func factoryRequest(_ creator: QualityProfile, idea: String) -> ScriptRequest {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile = creator.full
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: profile, scriptLanguage: creator.language, interfaceLanguage: creator.language
        )
        return factory.request(idea: idea, platform: .reels, format: nil)
    }

    // MARK: - Routes

    @Test(arguments: [AIModelRoute.onDevice, .privateCloud])
    func bothAppleIntelligenceRoutesGetTheProof(route: AIModelRoute) {
        let instructions = ScriptPromptBuilder.instructions(for: AIRequestPolicy.prepare(request(), on: route))
        #expect(instructions.contains(Self.header), "\(route)")
        for marker in Self.markers { #expect(instructions.contains(marker), "\(route): \(marker)") }
    }

    @Test func ideasAndRewritesInPrivateCloudComputeGetTheProofToo() {
        let ideas = ScriptPromptBuilder.themesInstructions(voice: voice(), voiceBudget: AIRequestPolicy.cloudVoiceBudget)
        let rewrite = ScriptPromptBuilder.rewriteInstructions(voice: voice())
        for marker in Self.markers {
            #expect(ideas.contains(marker))
            #expect(rewrite.contains(marker))
        }
    }

    @Test func ultraAIGetsTheVoiceButNeverTheProof() {
        var request = request()
        request.engine = .ultra
        let payload = UltraPayload(request)
        let fit = UltraFitRequest(
            script: "Script.", platform: request.platform, range: request.targetRange, voice: request.voice, brand: nil, countShown: "40"
        ).stage
        let sent = [payload.draft, payload.check(of: "Draft."), payload.review(of: "Draft."), fit].flatMap { [$0.instructions, $0.prompt] }
        var plain = request
        plain.voice = nil
        #expect(payload.draft.prompt != UltraPayload(plain).draft.prompt, "the voice itself goes")
        for text in sent {
            for marker in Self.markers { #expect(!text.contains(marker)) }
        }
    }

    // MARK: - Budget and sizes

    /// The most proof a creator can hold (three pasted examples of the longest that is sent, three approved scripts, imported excerpts) fits the
    /// cloud's voice budget whole: nothing is trimmed, as on the device the examples are cut first only when the voice runs long.
    @Test func theMostProofFitsTheCloudBudgetWhole() {
        var voice = QualityProfiles.portuguese.full.voice(inLanguage: "pt")
        let long = String(repeating: "Fala, galera! Usa só um pontinho e espalha com o dedo. ", count: 8)
        voice.examples = (0..<VoiceExample.limit).map { VoiceExample(text: "\($0) \(long)") }
        voice.approvedSamples = (0..<VoiceLimits.approvedSamples).map { VoiceExample(text: "\($0) aprovado \(long)") }
        voice.excerpts = [VoiceExcerpt(text: long, language: "pt"), VoiceExcerpt(text: "Outro \(long)", language: "pt")]
        let brief = VoiceBriefBuilder.brief(for: voice, budget: AIRequestPolicy.cloudVoiceBudget, contextualPreferences: true)
        #expect(brief.cost <= AIRequestPolicy.cloudVoiceBudget)
        #expect(brief.trimmed.isEmpty, "\(brief.trimmed)")
        let lines = brief.text.components(separatedBy: "\n")
        let shown = lines.drop { !$0.hasPrefix(Self.header) }.dropFirst().prefix { $0.hasPrefix("- “") }
        #expect(shown.count == VoiceExample.limit, "the same three examples the device sends")
        let device = VoiceBriefBuilder.brief(for: voice)
        #expect(device.trimmed.contains(.examples), "the device's 2100 shortens them; the cloud's 6000 doesn't need to")
    }

    /// What Private Cloud Compute is sent for each quality creator, kept with its size before the proof (as it went until 02/11) and after.
    @Test(arguments: QualityProfiles.all)
    func thePrivateCloudPromptMatchesTheKeptSnapshot(creator: QualityProfile) throws {
        let request = AIRequestPolicy.prepare(factoryRequest(creator, idea: creator.ideas[0]), on: .privateCloud)
        var before = request
        before.voice?.examples = []
        before.voice?.excerpts = []
        before.voice?.approvedSamples = []
        let size = { (request: ScriptRequest) -> (units: Int, tokens: Int) in
            let text = ScriptPromptBuilder.instructions(for: request) + "\n" + ScriptPromptBuilder.prompt(for: request)
            return (PromptCost.units(of: text), PromptCost.tokens(of: text))
        }
        let (old, new) = (size(before), size(request))
        let voice = try #require(request.voice)
        let oldVoice = try #require(before.voice)
        let brief = VoiceBriefBuilder.brief(for: voice, budget: AIRequestPolicy.cloudVoiceBudget, contextualPreferences: true)
        let oldBrief = VoiceBriefBuilder.brief(for: oldVoice, budget: AIRequestPolicy.cloudVoiceBudget, contextualPreferences: true)
        #expect(brief.cost <= AIRequestPolicy.cloudVoiceBudget && brief.trimmed.isEmpty)
        #expect(new.units > old.units, "the proof is in the request")
        let text = """
        PRIVATE CLOUD COMPUTE · \(creator.language.rawValue) · "\(creator.ideas[0])"
        VOICE \(oldBrief.cost) → \(brief.cost) / \(AIRequestPolicy.cloudVoiceBudget) UNITS · REQUEST \(old.units) → \(new.units) UNITS, \
        ≈\(old.tokens) → ≈\(new.tokens) TOKENS (estimated on the iPhone's weights, not Private Cloud Compute's count)

        INSTRUCTIONS
        \(ScriptPromptBuilder.instructions(for: request))

        PROMPT
        \(ScriptPromptBuilder.prompt(for: request))
        """
        try TextSnapshot.expect(text, named: creator.language.rawValue, in: "VoiceBriefs/pcc")
    }

    // MARK: - The meter

    @Test func theMeterIsWhatCueKnows() {
        #expect(VoiceMeter.title == "What Cue knows")
        #expect(VoiceMeter.caption(72) == "WHAT CUE KNOWS 72%")
    }

    /// The meter counts the proof, and the proof reaches both routes it counts for: one number, no second one for Private Cloud Compute.
    @Test func theProofTheMeterCountsReachesBothRoutes() {
        var profile = QualityProfiles.english.full
        let counted = profile.points(for: .examples)
        #expect(counted > 0)
        let request = factoryRequest(QualityProfiles.english, idea: QualityProfiles.english.ideas[0])
        for route in [AIModelRoute.onDevice, .privateCloud] {
            let instructions = ScriptPromptBuilder.instructions(for: AIRequestPolicy.prepare(request, on: route))
            #expect(instructions.contains(Self.header), "\(route) gets the \(counted) points of proof")
        }
        profile.examples = []
        profile.approvedSamples = []
        profile.excerpts = []
        profile.approvals = 0
        #expect(profile.points(for: .examples) == 0)
        #expect(profile.voiceStrength == QualityProfiles.english.full.voiceStrength - counted)
    }

    // MARK: - What the creator reads

    @Test func theTextsSayWhereTheProofGoes() {
        #expect(AIDisclosure.privateCloud.contains("examples included"))
        #expect(AIDisclosure.proof.contains("Private Cloud Compute") && AIDisclosure.proof.contains("Ultra AI never gets them"))
        #expect(AIDisclosure.example.contains("Never sent to Ultra AI"))
        #expect(AIDisclosure.ultraSends.contains("everything but your examples"))
        #expect(AIDisclosure.ultraPrivacy.contains("never go to Google"))
        let texts = [
            AIDisclosure.privateCloud, AIDisclosure.proof, AIDisclosure.example, AIDisclosure.ultraSends, AIDisclosure.ultraPrivacy,
            FeatureID.importWriting.notificationBody,
        ]
        for text in texts {
            #expect(!text.lowercased().contains("stay on this iphone") && !text.lowercased().contains("stays on this iphone"), "\(text)")
            #expect(!text.contains("never sent to Private Cloud Compute"), "\(text)")
        }
    }
}
