//
//  ScriptQualityDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import FoundationModels
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// The measurement behind the script engineering work: for a creator in English, Brazilian Portuguese and Spanish (`QualityProfiles`), with My Cue
/// Voice answered in full, half-way and off, the real Apple Intelligence model writes two free ideas and a Find inspiration brief, through the
/// service and the request factory the app uses, and two batches of Find inspiration ideas. Each script is kept with what was sent (instructions,
/// prompt), what it cost the window (tokens of the instructions, the prompt and the answer's structure, `tokenCount(for:)`), the draft that was
/// not kept when there were two, and the seconds; each batch with its briefs. The metrics are computed later from the kept texts
/// (`ScriptQualityReportTests`), so a run can be compared with another after the metrics change.
///
/// Opt-in and on a device with Apple Intelligence on, unlocked and awake:
/// `CUE_DEVICE=<iPhone> TEST_RUNNER_CUE_QUALITY_RUN=baseline scripts/test.sh device ScriptQualityDeviceTests`. `TEST_RUNNER_CUE_QUALITY_LANGUAGES=pt-BR,es-ES`
/// and `TEST_RUNNER_CUE_QUALITY_CONDITIONS=full,half` narrow it.
///
/// The sweep of all 20 languages (`sweepsEveryLanguage`, condition "sweep", no voice) also needs `TEST_RUNNER_CUE_QUALITY_SWEEP=1`; on its own, in a
/// run of its own name: `TEST_RUNNER_CUE_QUALITY_SWEEP=1 TEST_RUNNER_CUE_QUALITY_RUN=sweep-1 scripts/test.sh device
/// "ScriptQualityDeviceTests/sweepsEveryLanguage(_:)"`, narrowed by `TEST_RUNNER_CUE_QUALITY_LANGUAGES` like the rest.
@MainActor
@Suite("Script quality on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct ScriptQualityDeviceTests {
    nonisolated struct Case: Sendable, CustomTestStringConvertible {
        let profile: QualityProfile
        let condition: QualityProfile.Condition
        var testDescription: String { "\(profile.language.rawValue)-\(condition.rawValue)" }
    }

    private static let run = ProcessInfo.processInfo.environment["CUE_QUALITY_RUN"] ?? "run"

    nonisolated static let cases: [Case] = {
        let environment = ProcessInfo.processInfo.environment
        let languages = environment["CUE_QUALITY_LANGUAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        let conditions = environment["CUE_QUALITY_CONDITIONS"].map { Set($0.split(separator: ",").map(String.init)) }
        return QualityProfiles.all.flatMap { profile in
            QualityProfile.Condition.allCases.map { Case(profile: profile, condition: $0) }
        }.filter { item in
            (languages?.contains(item.profile.language.rawValue) ?? true) && (conditions?.contains(item.condition.rawValue) ?? true)
        }
    }()

    /// The languages of the sweep, narrowed by `CUE_QUALITY_LANGUAGES` as the cases are.
    nonisolated static let sweeps: [LanguageSweepCase] = {
        let languages = ProcessInfo.processInfo.environment["CUE_QUALITY_LANGUAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        return LanguageSweepCases.all.filter { languages?.contains($0.language.rawValue) ?? true }
    }()

    /// The condition the sweep's samples are kept under (`QualityRunSample.condition`).
    private static let sweepCondition = "sweep"

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private static let pause: Duration = .seconds(3)
    private static let rateLimitPause: Duration = .seconds(30)

    private func ready() throws -> ScriptAIService {
        KeepScreenAwake.enable()
        // `TEST_RUNNER_CUE_QUALITY_SUBSTANCE=off`: the request as it was before the opening was held to the subject (`forbidsFillerOpening`).
        ScriptPromptBuilder.forbidsFillerOpening = ProcessInfo.processInfo.environment["CUE_QUALITY_SUBSTANCE"] != "off"
        let service = ScriptAIService()
        guard service.availability.onDevice else {
            try Test.cancel("Apple Intelligence isn't available on this device: \(service.availability.reason ?? "unknown")")
        }
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on: the model is rate limited in the background")
        #endif
        return service
    }

    // MARK: - Scripts

    @Test(arguments: ScriptQualityDeviceTests.cases)
    func writesTheScripts(_ item: Case) async throws {
        let service = try ready()
        var samples: [QualityRunSample] = []
        // `TEST_RUNNER_CUE_QUALITY_BRIEF_REPS=<n>`: only the Find inspiration brief, n times (indexes from 10), to count how often it fails.
        let reps = ProcessInfo.processInfo.environment["CUE_QUALITY_BRIEF_REPS"].flatMap(Int.init)
        let entries: [(offset: Int, element: (idea: String, brief: IdeaBrief?))] = reps.map { count in
            (0..<count).map { (offset: 10 + $0, element: (idea: item.profile.brief.composerText, brief: Optional(item.profile.brief))) }
        } ?? item.profile.cases.enumerated().map { (offset: $0.offset, element: $0.element) }
        for (index, entry) in entries {
            let request = Self.request(for: entry.idea, brief: entry.brief, profile: item.profile, condition: item.condition)
            let sample = await Self.script(
                request, idea: entry.idea, language: item.profile.language, condition: item.condition.rawValue, index: index, service: service
            )
            samples.append(sample)
            Self.record(sample, named: "quality-sample-\(Self.run)-script-\(item.testDescription)-\(index).json")
            try await Task.sleep(for: Self.pause)
        }
        #expect(samples.contains { $0.wasWritten }, "at least one script was written")
    }

    /// The request the card sends for `idea`, built by the factory the app uses, the interface in the creator's language.
    static func request(for idea: String, brief: IdeaBrief?, profile: QualityProfile, condition: QualityProfile.Condition) -> ScriptRequest {
        request(for: idea, brief: brief, creator: profile.profile(condition), language: profile.language)
    }

    /// The request the card sends for `idea` from `creator`, built by the factory the app uses, the interface (and the iPhone) in `language`.
    static func request(for idea: String, brief: IdeaBrief?, creator: CreatorProfile, language: CueLanguage) -> ScriptRequest {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = CreatorProfileService(defaults: defaults.defaults)
        service.profile = creator
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: service, scriptLanguage: nil, interfaceLanguage: language, preferredLanguages: [language.rawValue]
        )
        return factory.request(idea: idea, platform: .tiktok, format: nil, brief: brief)
    }

    /// One script written from `request` through the service the app uses, kept with what was sent, what it cost the window and how long it took.
    /// A rate limit (the model's, in bursts) is waited out twice; any other failure is kept as it came, with why the answer was empty.
    private static func script(
        _ request: ScriptRequest, idea: String, language: CueLanguage, condition: String, index: Int, service: ScriptAIService
    ) async -> QualityRunSample {
        var sample = QualityRunSample(
            kind: "script", run: run, language: language.rawValue, condition: condition, index: index, idea: idea, hasBrief: request.brief != nil,
            seconds: 0
        )
        await measureRequest(request, into: &sample)
        let started = ContinuousClock.now
        for attempt in 1...3 {
            do {
                let script = try await service.generate(request)
                sample.title = script.title
                sample.text = script.text
                sample.discardedDraft = script.discardedDraft
                sample.progressionDefects = script.progressionDefects.map(\.rawValue)
                sample.attempts = script.attempts
                sample.violations = script.voiceViolations.map(\.rawValue)
                sample.expandedBlocks = script.expandedBlocks
                sample.voiceUse = script.voiceUse.rawValue
                sample.firstResponse = script.timings?.firstResponse?.inSeconds
                sample.outputTokens = try? await SystemLanguageModel.default.tokenCount(for: script.text)
                sample.failure = nil
                break
            } catch ScriptAIError.rateLimited where attempt < 3 {
                try? await Task.sleep(for: rateLimitPause)
            } catch {
                sample.failure = "\(error)"
                sample.emptyReason = ScriptAIService.lastEmptyReason
                break
            }
        }
        sample.seconds = started.duration(to: .now).inSeconds
        print(line(for: sample))
        return sample
    }

    /// Kept as an attachment of the test, which `tools/quality/collect.py` gathers from the result bundle.
    private static func record(_ sample: QualityRunSample, named name: String) {
        if let data = try? encoder.encode(sample) {
            Attachment.record(data, named: name)
        }
    }

    /// What the request costs the model's window, measured by the model's own tokenizer.
    private static func measureRequest(_ request: ScriptRequest, into sample: inout QualityRunSample) async {
        let model = SystemLanguageModel.default
        let instructions = ScriptPromptBuilder.instructions(for: request)
        let prompt = ScriptPromptBuilder.prompt(for: request)
        sample.instructions = instructions
        sample.prompt = prompt
        sample.instructionTokens = try? await model.tokenCount(for: Instructions(instructions))
        sample.promptTokens = try? await model.tokenCount(for: prompt)
        sample.schemaTokens = try? await model.tokenCount(for: ScriptDraft.generationSchema)
        sample.contextSize = model.contextSize
        let counting = ContinuousClock.now
        _ = await OnDeviceMeasure().tokens(instructions: instructions, prompt: prompt, structure: .script)
        sample.countMilliseconds = counting.duration(to: .now).inSeconds * 1000
        sample.responseCap = ScriptAIService.responseTokens(for: request)
        sample.minimumWords = ReadTime.words(for: request.targetRange.lowerBound)
        let asked = ScriptPromptBuilder.askedRange(for: request.targetRange)
        sample.askedWords = [asked.low, asked.high]
        sample.voiceTrimmed = request.voice.map { VoiceBriefBuilder.brief(for: $0, register: PlatformRegister(request.platform)).trimmed.map(\.rawValue) }
    }

    // MARK: - Find inspiration

    @Test(arguments: ScriptQualityDeviceTests.cases)
    func suggestsTheIdeas(_ item: Case) async throws {
        guard ProcessInfo.processInfo.environment["CUE_QUALITY_BRIEF_REPS"] == nil else { return }
        let service = try ready()
        let profile = item.profile.profile(item.condition)
        let language = item.profile.language
        let voice = item.condition == .none ? nil : profile.voice(inLanguage: language.locale.language.languageCode?.identifier)
        let topics = profile.ideaTopics.isEmpty ? [IdeaTopic.lifestyle] : profile.ideaTopics
        let taste = IdeaTaste()
        var written = 0
        for batch in 0..<2 {
            let slots = taste.slots(round: batch, among: topics)
            let sample = await Self.ideas(
                slots: slots, language: language, voice: voice, inspiration: item.profile.notes, condition: item.condition.rawValue, index: batch,
                service: service
            )
            written += sample.ideas?.count ?? 0
            Self.record(sample, named: "quality-sample-\(Self.run)-ideas-\(item.testDescription)-\(batch).json")
            try await Task.sleep(for: Self.pause)
        }
        #expect(written > 0, "at least one idea was written")
    }

    /// One batch of Find inspiration briefs for `slots`, kept with what was sent and what it cost the window.
    private static func ideas(
        slots: [IdeaSlot], language: CueLanguage, voice: CreatorVoice?, inspiration: [String], condition: String, index: Int, service: ScriptAIService
    ) async -> QualityRunSample {
        var sample = QualityRunSample(
            kind: "ideas", run: run, language: language.rawValue, condition: condition, index: index,
            idea: slots.map { "\($0.angle.rawValue)@\($0.topic.label)" }.joined(separator: ", "), hasBrief: true, seconds: 0
        )
        let prompt = ScriptPromptBuilder.themesPrompt(slots: slots, language: language, inspiration: inspiration, asBriefs: true)
        let instructions = ScriptPromptBuilder.themesInstructions(voice: voice)
        sample.instructions = instructions
        sample.prompt = prompt
        sample.instructionTokens = try? await SystemLanguageModel.default.tokenCount(for: Instructions(instructions))
        sample.promptTokens = try? await SystemLanguageModel.default.tokenCount(for: prompt)
        sample.schemaTokens = try? await SystemLanguageModel.default.tokenCount(for: IdeaBriefSuggestions.generationSchema)
        let started = ContinuousClock.now
        do {
            let ideas = try await service.suggestIdeas(slots: slots, language: language, voice: voice, inspiration: inspiration)
            sample.ideas = ideas.map { idea in
                QualityRunSample.Idea(
                    title: idea.title, angle: idea.brief?.angle ?? "", openingLine: idea.brief?.openingLine ?? "", angleKind: idea.angle,
                    topic: idea.topic ?? idea.niche.rawValue
                )
            }
        } catch {
            sample.failure = "\(error)"
        }
        sample.seconds = started.duration(to: .now).inSeconds
        print("QUALITY \(run) ideas \(language.rawValue)-\(condition)[\(index)] \(sample.ideas?.count ?? 0) ideas · " + String(format: "%.1f s", sample.seconds))
        for idea in sample.ideas ?? [] { print("QUALITY   \(idea.angleKind ?? "?") · \(idea.title) | \(idea.angle) | \(idea.openingLine)") }
        return sample
    }

    // MARK: - Every language

    /// The 20 languages for a creator who has not set up My Cue Voice (voice off, Lifestyle, the interface and the iPhone in the language): the free
    /// idea and the brief as two scripts, then one batch of Find inspiration ideas. Each language is three model calls and two pauses, about a
    /// minute, far from a device test's five.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CUE_QUALITY_SWEEP"] != nil), arguments: ScriptQualityDeviceTests.sweeps)
    func sweepsEveryLanguage(_ sweep: LanguageSweepCase) async throws {
        let service = try ready()
        let language = sweep.language
        let creator = CreatorProfile(niches: [.lifestyle], usesVoiceInAI: false)
        let entries: [(idea: String, brief: IdeaBrief?)] = [(sweep.idea, nil), (sweep.brief.composerText, sweep.brief)]
        var written = 0
        for (index, entry) in entries.enumerated() {
            let request = Self.request(for: entry.idea, brief: entry.brief, creator: creator, language: language)
            let sample = await Self.script(
                request, idea: entry.idea, language: language, condition: Self.sweepCondition, index: index, service: service
            )
            if sample.wasWritten { written += 1 }
            Self.record(sample, named: "quality-sample-\(Self.run)-sweep-script-\(language.rawValue)-\(index).json")
            try await Task.sleep(for: Self.pause)
        }
        let slots = IdeaTaste().slots(round: 0, among: [IdeaTopic.lifestyle])
        let batch = await Self.ideas(
            slots: slots, language: language, voice: nil, inspiration: [], condition: Self.sweepCondition, index: 0, service: service
        )
        Self.record(batch, named: "quality-sample-\(Self.run)-sweep-ideas-\(language.rawValue)-0.json")
        #expect(written > 0, "at least one script was written in \(language.rawValue)")
        #expect(batch.wasWritten, "ideas were written in \(language.rawValue)")
    }

    private static func line(for sample: QualityRunSample) -> String {
        let words = sample.text.map { ReadTime.wordCount(in: CueParser.stripCues($0)) } ?? 0
        let head = sample.text.map { String($0.prefix(80)).replacingOccurrences(of: "\n", with: " ") } ?? sample.failure ?? "nothing"
        let tokens = (sample.instructionTokens ?? 0) + (sample.promptTokens ?? 0) + (sample.schemaTokens ?? 0)
        return "QUALITY \(sample.run) script \(sample.language)-\(sample.condition)[\(sample.index)] · \(words) words · \(tokens) tokens in · "
            + String(format: "%.1f s", sample.seconds) + " · attempts \(sample.attempts ?? 0) · defects \(sample.progressionDefects ?? []) · “\(head)”"
    }
}
