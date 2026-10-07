//
//  WritingImportDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// Does importing a creator's writing make the scripts sound more like them? Each creator gets their three ideas written by the real model with
/// the voice as My Cue Voice holds it ("voice") and with the writing they imported on top of it ("imported"), through the service and the request
/// factory the app uses, and the scripts are measured against the habits of the writing itself (sentence length, exclamations, questions): the
/// nearer, the more it sounds like them. The scripts are kept as attachments so a person can read them side by side.
///
/// Opt-in and on a device with Apple Intelligence on, unlocked and awake: `CUE_DEVICE=<iPhone> scripts/test.sh device WritingImportDeviceTests`.
/// `TEST_RUNNER_CUE_IMPORT_CREATORS=maya,daniel` picks which creators to run (a run past ten minutes is stopped).
@MainActor
@Suite("Import my writing on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct WritingImportDeviceTests {
    /// A made-up creator and the writing they would bring from another app.
    struct Creator: Sendable, CustomTestStringConvertible {
        let id: String
        let persona: String
        let writing: [String]
        var testDescription: String { id }
    }

    nonisolated static let creators: [Creator] = {
        let all = [
            Creator(id: "maya", persona: "yoga-teacher", writing: WritingSamples.maya),
            Creator(id: "daniel", persona: "saas-founder", writing: WritingSamples.daniel),
            Creator(id: "rafa", persona: "mom-creator-pt-br", writing: WritingSamples.rafa),
        ]
        guard let named = ProcessInfo.processInfo.environment["CUE_IMPORT_CREATORS"], !named.isEmpty else { return all }
        let ids = Set(named.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        return all.filter { ids.contains($0.id) }
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    /// What a script says of the habits that were measured.
    private struct Habits {
        var wordsPerSentence = 0.0
        var exclamationShare = 0.0
        var questionShare = 0.0

        init(of text: String, language: String?) {
            let spoken = CueParser.stripCues(text)
            let sentences = WritingText.sentences(in: spoken, language: language)
            guard !sentences.isEmpty else { return }
            wordsPerSentence = Double(WritingText.words(in: spoken, language: language).count) / Double(sentences.count)
            exclamationShare = Double(sentences.filter(WritingText.isExclamation).count) / Double(sentences.count)
            questionShare = Double(sentences.filter(WritingText.isQuestion).count) / Double(sentences.count)
        }
    }

    /// The creator as they are after the four questions of the setup and nothing else: who they are, what about, who to, how they sound.
    private func essentialsOnly(_ persona: VoicePersona) -> CreatorProfile {
        let full = persona.profile
        var profile = CreatorProfile()
        profile.role = full.role
        profile.customRole = full.customRole
        profile.niches = full.niches
        profile.voiceTopics = full.voiceTopics
        profile.sounds = full.sounds
        profile.vocabulary = full.vocabulary
        profile.confirmedVoiceSteps = [.audience, .tone]
        profile.usesVoiceInAI = true
        return profile
    }

    /// Everything the creator accepts from the review (all of it on), applied the way the app applies it.
    private func accepting(_ proposal: WritingImportProposal, into profile: CreatorProfile, defaults: UserDefaults) -> CreatorProfile {
        let service = CreatorProfileService(defaults: defaults)
        service.profile = profile
        var everything = proposal
        for index in everything.findings.indices { everything.findings[index].isOn = true }
        service.apply(everything)
        return service.profile
    }

    @Test(arguments: WritingImportDeviceTests.creators)
    func importedWritingMovesScriptsTowardTheCreatorsOwnHabits(creator: Creator) async throws {
        KeepScreenAwake.enable()
        let service = ScriptAIService()
        guard service.availability.onDevice else { try Test.cancel("Apple Intelligence isn't available on this device") }
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on: the model is rate limited in the background")
        #endif
        let persona = try #require(VoicePersonas.persona(creator.persona))
        let analysis = WritingAnalyzer.analyze(creator.writing.map { WritingPiece(text: $0) })
        let target = try #require(analysis.fingerprint)
        let base = essentialsOnly(persona)
        // The review as the model on this iPhone writes it, then everything on, as a creator coming from another app would accept it.
        let reading = await AppleWritingStyleReader().read(analysis.excerpts.map(\.text), language: analysis.language)
        let proposal = WritingImportProposalBuilder.build(analysis: analysis, reading: reading, profile: base)
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let accepted = accepting(proposal, into: base, defaults: defaults.defaults)
        var findingsOnly = accepted
        findingsOnly.excerpts = []
        findingsOnly.fingerprint = nil
        var excerptsOnly = base
        excerptsOnly.excerpts = accepted.excerpts
        excerptsOnly.fingerprint = accepted.fingerprint
        print(String(
            format: "IMPORT %@ target wps=%.1f excl=%.2f question=%.2f excerpts=%d findings=%d model=%@ phrases=%@",
            creator.id, target.wordsPerSentence, target.exclamationShare, target.questionShare, analysis.excerpts.count, proposal.findings.count,
            reading == nil ? "no" : "yes", accepted.phrases.joined(separator: "|")
        ))
        // Two conditions keep a creator within the five minutes a test is given; `TEST_RUNNER_CUE_IMPORT_CONDITIONS=essentials,findings,excerpts,imported`
        // takes them all, one idea at a time (`TEST_RUNNER_CUE_IMPORT_IDEA=0`).
        let wanted = ProcessInfo.processInfo.environment["CUE_IMPORT_CONDITIONS"].map { Set($0.split(separator: ",").map(String.init)) }
            ?? ["essentials", "imported"]
        let conditions = [("essentials", base), ("findings", findingsOnly), ("excerpts", excerptsOnly), ("imported", accepted)]
            .filter { wanted.contains($0.0) }
        let only = ProcessInfo.processInfo.environment["CUE_IMPORT_IDEA"].flatMap { Int($0) }
        var results: [String: [Habits]] = [:]
        for (index, idea) in persona.ideas.enumerated() where only == nil || only == index {
            for (condition, profile) in conditions {
                let request = persona.request(for: idea, withVoice: true, profile: profile)
                let started = ContinuousClock.now
                let script: GeneratedScript
                do {
                    script = try await Self.generate(request, with: service)
                } catch {
                    print("IMPORT \(creator.id)[\(index)] \(condition) failed: \(error)")
                    continue
                }
                let habits = Habits(of: script.text, language: target.language)
                results[condition, default: []].append(habits)
                let sample = VoiceRunSample(
                    persona: persona.id, ideaIndex: index, idea: idea, condition: condition, run: "import", title: script.title,
                    text: script.text, failure: nil, seconds: started.duration(to: .now).inSeconds, attempts: script.attempts
                )
                if let data = try? Self.encoder.encode(sample) { Attachment.record(data, named: "import-sample-\(creator.id)-\(index)-\(condition).json") }
                let said = accepted.phrases.contains { CueParser.stripCues(script.text).localizedCaseInsensitiveContains($0) }
                print(String(
                    format: "IMPORT %@[%d] %@ wps=%.1f excl=%.2f question=%.2f phrase=%@ violations=%@ · %.0f s",
                    creator.id, index, condition, habits.wordsPerSentence, habits.exclamationShare, habits.questionShare, said ? "yes" : "no",
                    script.voiceViolations.map(\.rawValue).joined(separator: ","), sample.seconds
                ))
                try await Task.sleep(for: .seconds(4))
            }
        }
        for (condition, _) in conditions {
            let list = results[condition] ?? []
            guard !list.isEmpty else { continue }
            let count = Double(list.count)
            let length = list.map { abs($0.wordsPerSentence - target.wordsPerSentence) / target.wordsPerSentence }.reduce(0, +) / count
            let exclamation = list.map { abs($0.exclamationShare - target.exclamationShare) }.reduce(0, +) / count
            let question = list.map { abs($0.questionShare - target.questionShare) }.reduce(0, +) / count
            print(String(
                format: "IMPORT %@ %@ n=%d length-distance=%.2f exclamation-distance=%.2f question-distance=%.2f",
                creator.id, condition, list.count, length, exclamation, question
            ))
        }
        #expect(results["imported"]?.isEmpty == false, "\(creator.id): at least one script was written with the writing")
    }

    private static func generate(_ request: ScriptRequest, with service: ScriptAIService) async throws -> GeneratedScript {
        for attempt in 1...3 {
            do {
                return try await service.generate(request)
            } catch ScriptAIError.rateLimited where attempt < 3 {
                try await Task.sleep(for: .seconds(30))
            }
        }
        return try await service.generate(request)
    }
}
