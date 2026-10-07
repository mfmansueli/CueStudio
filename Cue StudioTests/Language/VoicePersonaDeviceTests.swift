//
//  VoicePersonaDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// The measurement behind My Cue Voice (plan §5 stage 0 and §6): every made-up creator (`VoicePersonas`) gets each of their three ideas
/// written by the real Apple Intelligence model, with "Write in my voice" off and on, through the service and the request factory the
/// app uses. The scripts are kept as `voice-run-<run>-<persona>.json` attachments of the result (`VoiceRunSample`), so the same twelve
/// creators can be written again after a change and compared (`VoiceRunMetrics`).
///
/// Opt-in and on a device with Apple Intelligence on, unlocked and awake (`CUE_DEVICE=<iPhone> scripts/test.sh device VoicePersonaDeviceTests`).
/// `TEST_RUNNER_CUE_VOICE_RUN=before` names the run (what the code was when it was written); `TEST_RUNNER_CUE_VOICE_PERSONAS` picks a few
/// creators (a test the plan runs past ten minutes is stopped). Whether a script *sounds like* the creator is for people to say: this only
/// writes and keeps them.
@MainActor
@Suite("My Cue Voice on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct VoicePersonaDeviceTests {
    private static let run = ProcessInfo.processInfo.environment["CUE_VOICE_RUN"] ?? "run"

    /// The personas to write for: all of them, or the ones named by `TEST_RUNNER_CUE_VOICE_PERSONAS=yoga-teacher,comedian`. A test that runs past
    /// ten minutes is stopped by the test plan, so a full run is made of a few of these.
    nonisolated static let personas: [VoicePersona] = {
        let all = VoicePersonas.all + VoicePersonas.languageVariants
        guard let named = ProcessInfo.processInfo.environment["CUE_VOICE_PERSONAS"], !named.isEmpty else { return all }
        let ids = Set(named.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        return all.filter { ids.contains($0.id) }
    }()

    /// The ideas to write: each creator's own three, or `TEST_RUNNER_CUE_VOICE_IDEAS=shared` for the three every creator writes (`VoicePersonas.sharedIdeas`),
    /// which is what lets the same idea be compared between creators.
    private static let usesSharedIdeas = ProcessInfo.processInfo.environment["CUE_VOICE_IDEAS"] == "shared"

    /// The conditions to write: both, or `TEST_RUNNER_CUE_VOICE_CONDITIONS=voice` for only the one that is compared between runs (a creator's six scripts
    /// can run past the five minutes a test is given, now that a short script is lengthened block by block).
    private static let conditions: [String] = {
        guard let named = ProcessInfo.processInfo.environment["CUE_VOICE_CONDITIONS"], !named.isEmpty else { return ["no-voice", "voice"] }
        let wanted = Set(named.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        return ["no-voice", "voice"].filter { wanted.contains($0) }
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    /// The model is rate limited after a long run of scripts: a pause between them, and a longer one when it says so.
    private static let pause: Duration = .seconds(4)
    private static let rateLimitPause: Duration = .seconds(30)

    @Test(arguments: VoicePersonaDeviceTests.personas)
    func writesEachIdeaWithAndWithoutTheVoice(persona: VoicePersona) async throws {
        KeepScreenAwake.enable()
        let service = ScriptAIService()
        guard service.availability.onDevice else {
            try Test.cancel("Apple Intelligence isn't available on this device: \(service.availability.reason ?? "unknown")")
        }
        // The model is rate limited in the background: with the iPhone locked or the screen off every request fails, and the run only fills
        // with failures.
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on: the model is rate limited in the background")
        #endif
        var samples: [VoiceRunSample] = []
        // The shared ideas are in English: a creator writing in another language is checked on their own.
        let ideas = Self.usesSharedIdeas ? (persona.language == .english ? VoicePersonas.sharedIdeas : []) : persona.ideas
        for (index, idea) in ideas.enumerated() {
            for condition in Self.conditions {
                let request = persona.request(for: idea, withVoice: condition == "voice")
                #expect((request.voice != nil) == (condition == "voice"), "\(persona.id): the voice follows the condition")
                let sample = await write(request, persona: persona, index: index, idea: idea, condition: condition, with: service)
                print(Self.line(for: sample))
                samples.append(sample)
                // Kept as soon as it is written: a run that dies (the iPhone locked, the model rate limited in the background) keeps what it did.
                if let data = try? Self.encoder.encode(sample) {
                    Attachment.record(data, named: "voice-sample-\(Self.run)-\(persona.id)-\(index)-\(condition).json")
                }
                try await Task.sleep(for: Self.pause)
            }
        }
        Attachment.record(try Self.encoder.encode(samples), named: "voice-run-\(Self.run)-\(persona.id).json")
        let written = samples.filter { $0.wasWritten }.count
        #expect(samples.isEmpty || written > 0, "\(persona.id): at least one script was written")
    }

    private func write(
        _ request: ScriptRequest, persona: VoicePersona, index: Int, idea: String, condition: String, with service: ScriptAIService
    ) async -> VoiceRunSample {
        let started = ContinuousClock.now
        var failure: String?
        var script: GeneratedScript?
        for attempt in 1...3 {
            do {
                script = try await service.generate(request)
                failure = nil
                break
            } catch ScriptAIError.rateLimited where attempt < 3 {
                try? await Task.sleep(for: Self.rateLimitPause)
            } catch {
                failure = "\(error)"
                break
            }
        }
        return VoiceRunSample(
            persona: persona.id, ideaIndex: index, idea: idea, condition: condition, run: Self.run,
            title: script?.title, text: script?.text, failure: failure,
            seconds: started.duration(to: .now).inSeconds, attempts: 1
        )
    }

    private static func line(for sample: VoiceRunSample) -> String {
        let words = sample.text.map { ReadTime.wordCount(in: CueParser.stripCues($0)) } ?? 0
        let head = sample.text.map { String($0.prefix(90)).replacingOccurrences(of: "\n", with: " ") } ?? sample.failure ?? "nothing"
        return "VOICE RUN \(sample.run) \(sample.persona)[\(sample.ideaIndex)] \(sample.condition) · \(words) words · "
            + String(format: "%.1f", sample.seconds) + " s · “\(head)”"
    }
}
