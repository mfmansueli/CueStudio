//
//  VoiceCheckedWritingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What happens around the model (plan stage 3, item 7): a script that breaks the creator's rules is written once more, a refusal of their own words
/// is answered with what Cue offers, and nothing ever blocks them.
@MainActor
@Suite("Voice checked writing")
struct VoiceCheckedWritingTests {
    private struct Refusal: Error {}
    private struct Failure: Error {}

    /// Scripts the fake model writes, in order, and what it was asked.
    @MainActor
    private final class Model {
        var outputs: [Result<GeneratedScript, any Error>]
        private(set) var asked: [(request: ScriptRequest, violations: [VoiceViolation])] = []
        private(set) var reported: [String] = []

        init(_ outputs: [Result<GeneratedScript, any Error>]) { self.outputs = outputs }

        func draft(_ request: ScriptRequest, _ violations: [VoiceViolation]) async throws -> GeneratedScript {
            asked.append((request, violations))
            guard !outputs.isEmpty else { throw Failure() }
            return try outputs.removeFirst().get()
        }

        var writing: VoiceCheckedWriting {
            VoiceCheckedWriting(
                draft: { [self] in try await draft($0, $1) },
                isGuardrailRefusal: { $0 is Refusal },
                report: { [self] _, step in reported.append(step) }
            )
        }
    }

    private static let clean = ok(text: Array(repeating: "plain words here", count: 20).joined(separator: " "))
    private static let hype = ok(text: "This is a game-changer " + Array(repeating: "plain words here", count: 20).joined(separator: " "))
    private static let veryHype = ok(text: "A game-changer, insane and unbelievable " + Array(repeating: "plain words here", count: 20).joined(separator: " "))

    private static func ok(text: String) -> Result<GeneratedScript, any Error> {
        .success(GeneratedScript(title: "T", text: text, usedLanguageModel: true))
    }

    private func request(voice: CreatorVoice? = nil) -> ScriptRequest {
        ScriptRequest(source: .prompt("Why mornings are hard"), platform: .tiktok, tone: nil, voice: voice, targetRange: 30...45)
    }

    private var avoidsHype: CreatorVoice {
        var voice = CreatorProfile(niches: [.tech], phrases: ["Hey fam"], avoid: ["Hype words", "get rich quick"], customTags: ["Likes tea"]).voice
        voice.avoid = ["Hype words", "get rich quick"]
        return voice
    }

    @Test func aScriptThatKeepsToTheRulesIsWrittenOnce() async throws {
        let model = Model([Self.clean])
        let script = try await model.writing.write(request(voice: avoidsHype))
        #expect(model.asked.count == 1 && model.asked[0].violations.isEmpty)
        #expect(script.attempts == 1 && script.voiceViolations.isEmpty && script.voiceUse == .full)
    }

    @Test func aScriptThatBreaksARuleIsWrittenOnceMoreToldWhichOne() async throws {
        let model = Model([Self.hype, Self.clean])
        let script = try await model.writing.write(request(voice: avoidsHype))
        #expect(model.asked.count == 2)
        #expect(model.asked[1].violations.map(\.kind) == [.avoided])
        #expect(model.asked[1].violations[0].detail.contains("game-changer"))
        #expect(script.attempts == 2 && script.voiceViolations.isEmpty)
        #expect(!script.text.contains("game-changer"))
    }

    @Test func aSecondScriptThatIsNoWorseIsTheOneTheCreatorGets() async throws {
        let model = Model([Self.veryHype, Self.hype])
        let script = try await model.writing.write(request(voice: avoidsHype))
        #expect(script.attempts == 2 && script.text.contains("game-changer") && !script.text.contains("insane"))
        #expect(script.voiceViolations == [.avoided])
    }

    @Test func aSecondScriptThatIsWorseIsNotUsed() async throws {
        let model = Model([Self.hype, Self.veryHype])
        let script = try await model.writing.write(request(voice: avoidsHype))
        #expect(model.asked.count == 2)
        #expect(script.attempts == 1 && !script.text.contains("insane"))
        #expect(script.voiceViolations == [.avoided], "what the script still breaks is counted, never told")
    }

    @Test func aSecondAttemptThatFailsLeavesTheFirstScript() async throws {
        let model = Model([Self.hype, .failure(Failure())])
        let script = try await model.writing.write(request(voice: avoidsHype))
        #expect(script.attempts == 1 && script.text.contains("game-changer"))
        #expect(model.reported == ["script.voiceRetry"])
    }

    @Test func cancellingTheSecondAttemptCancelsTheWriting() async {
        let model = Model([Self.hype, .failure(CancellationError())])
        await #expect(throws: CancellationError.self) { try await model.writing.write(request(voice: avoidsHype)) }
    }

    @Test func aScriptTooShortIsNotWrittenAgainButLeftToBeLengthened() async throws {
        let short = Self.ok(text: "Too short.")
        let model = Model([short, Self.clean])
        let script = try await model.writing.write(request())
        #expect(model.asked.count == 1, "a whole second attempt is not what makes it longer (measured on an iPhone: 54 words, then 64 to 86)")
        #expect(script.attempts == 1 && script.voiceViolations == [.tooShort])
    }

    @Test func aScriptTooShortAndBreakingARuleIsWrittenOnceMoreAndToldBoth() async throws {
        let model = Model([Self.ok(text: "A game-changer."), Self.clean])
        let script = try await model.writing.write(request(voice: avoidsHype))
        #expect(model.asked.count == 2)
        #expect(Set(model.asked[1].violations.map(\.kind)) == [.avoided, .tooShort])
        #expect(script.attempts == 2)
    }

    @Test func aStructuredDraftWithNoModelIsNeverChecked() async throws {
        let draft = GeneratedScript(title: "T", text: "Too short.", usedLanguageModel: false)
        let model = Model([.success(draft)])
        let script = try await model.writing.write(request(voice: avoidsHype))
        #expect(model.asked.count == 1 && script.attempts == 1)
    }

    // MARK: - Refusals

    @Test func theModelRefusingTheCreatorsOwnWordsIsAnsweredWithWhatCueOffers() async throws {
        let model = Model([.failure(Refusal()), Self.clean])
        let script = try await model.writing.write(request(voice: avoidsHype))
        #expect(model.asked.count == 2)
        let sent = try #require(model.asked[1].request.voice)
        #expect(sent.phrases.isEmpty, "the typed catchphrase is not sent again")
        #expect(sent.avoid == ["Hype words"], "what the creator typed to avoid is not sent again; what Cue offers is")
        #expect(sent.customTags.isEmpty)
        #expect(script.voiceUse == .catalogOnly)
        #expect(model.reported == ["script"])
    }

    @Test func aRefusalWithNoVoiceIsNotAnsweredWithAnother() async {
        let model = Model([.failure(Refusal())])
        await #expect(throws: Refusal.self) { try await model.writing.write(request()) }
        #expect(model.asked.count == 1)
    }

    @Test func aRefusalOfTheCatalogOnlyVoiceToo() async {
        let model = Model([.failure(Refusal()), .failure(Refusal())])
        await #expect(throws: Refusal.self) { try await model.writing.write(request(voice: avoidsHype)) }
        #expect(model.asked.count == 2, "asked once more, never a third time")
    }

    @Test func anyOtherErrorGoesToTheCaller() async {
        let model = Model([.failure(Failure())])
        await #expect(throws: Failure.self) { try await model.writing.write(request(voice: avoidsHype)) }
        #expect(model.asked.count == 1)
    }

    // MARK: - The voice without what the creator typed

    @Test func theCatalogOnlyVoiceKeepsWhatCueOffersAndLosesWhatWasTyped() {
        let profile = CreatorProfile(
            niches: [.fitness], customTopics: ["Chess"], phrases: ["Hey fam"], role: .expert, openings: ["Question", "my own way"],
            endings: ["Save this", "See you Sunday"], avoid: ["Clickbait", "get rich quick"], examples: [VoiceExample(text: "Okay, real talk.")],
            customTags: ["Likes tea"], topicDetails: ["fitness": ["Running", "Kettlebell flows"]], audienceNote: "Nurses", customRole: "Chess coach",
            credential: "Registered nurse", approvedSamples: [VoiceExample(text: "Approved")]
        )
        let safe = profile.voice.catalogOnly
        #expect(safe.topics == [VoiceTopicEntry(topic: .niche(.fitness), subtopics: ["Running"])])
        #expect(safe.openings == ["Question"] && safe.endings == ["Save this"] && safe.avoid == ["Clickbait"])
        #expect(safe.phrases.isEmpty && safe.examples.isEmpty && safe.approvedSamples.isEmpty && safe.customTags.isEmpty)
        #expect(safe.audienceNote == nil && safe.customRole == nil && safe.credential == nil)
        #expect(safe.role == .expert, "the kind of creator is Cue's")
    }
}
