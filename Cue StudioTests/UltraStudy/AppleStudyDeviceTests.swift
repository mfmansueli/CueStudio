//
//  AppleStudyDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// The Ultra study's requests written by Apple Intelligence on this iPhone (the owner, 04/11/2026: bring the study's improvements to Apple
/// Intelligence and measure them on every iPhone we have). Each job is a case of `tools/ultra/study/cases`, a route (the device's model or
/// Private Cloud Compute), the improvements it has on (`ScriptPromptBuilder.definesFormats`, `followsIdeaKind`) and the part of the network's
/// range it aims at (`AppleScriptLength.window`). The jobs come in
/// `CUE_APPLE_STUDY_JOBS` (base64 JSON, a few a run, from `tools/ultra/study/apple_run.py`); each script is kept as an attachment in the study's
/// record shape, which apple_run.py exports to the study folder's `out/` for blind.py and score.py.
///
///     tools/ultra/study/apple_run.py --cases tools/ultra/study/cases/phase4.json --route onDevice --device "iago Lima iphone" --out <folder>
@MainActor
@Suite("The Ultra study on Apple Intelligence", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_APPLE_STUDY_E2E"] != nil))
struct AppleStudyDeviceTests {
    nonisolated static let jobs: [AppleStudyJob] = {
        guard let text = ProcessInfo.processInfo.environment["CUE_APPLE_STUDY_JOBS"], let data = Data(base64Encoded: text) else { return [] }
        return (try? JSONDecoder().decode([AppleStudyJob].self, from: data)) ?? []
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let pause: Duration = .seconds(3)
    private static let rateLimitPause: Duration = .seconds(30)

    @Test(arguments: jobs)
    func writes(_ job: AppleStudyJob) async throws {
        KeepScreenAwake.enable()
        let window = job.window.flatMap { $0.count == 2 && $0[0] <= $0[1] ? $0[0]...$0[1] : nil } ?? AppleScriptLength.window
        try await AppleScriptLength.$window.withValue(window) {
            try await ScriptPromptBuilder.$definesFormats.withValue(job.variants.contains("formatDefinitions")) {
                try await ScriptPromptBuilder.$followsIdeaKind.withValue(job.variants.contains("ideaKind")) {
                    try await write(job)
                }
            }
        }
    }

    private func write(_ job: AppleStudyJob) async throws {
        let route = try #require(AIModelRoute(rawValue: job.route), "Unknown route \(job.route)")
        let local = route == .onDevice
        let service = ScriptAIService(usesPrivateCloudCompute: !local, preferredModel: local ? nil : .privateCloud)
        if !local, !service.availability.privateCloud {
            try Test.cancel("Private Cloud Compute is unavailable: this route is not validated")
        }
        guard local ? service.availability.onDevice : service.availability.isAvailable else {
            try Test.cancel("Apple Intelligence isn't available on this device: \(service.availability.reason ?? "unknown")")
        }
        #if canImport(UIKit)
        try #require(UIApplication.shared.applicationState == .active, "The iPhone must be unlocked with the screen on")
        #endif
        var request = try job.item.request(engine: .apple)
        // On Auto the device's request says no length ("informative"), so a window changes nothing it is told: a job that targets its window
        // asks for it in words, as a chosen length does, for every case on Auto (a creator's usual length aside), to see where it writes best.
        if job.variants.contains("targetsWindow"), request.durationPolicy == .informative {
            request.targetRange = AppleScriptLength.window(within: ScriptRequestFactory.writingRange)
            request.durationPolicy = .targeted
        }
        let prepared = AIRequestPolicy.prepare(request, on: route)
        var record = AppleStudyRecord(
            job: AppleStudyJobShape(
                id: job.id, item: job.item, config: AppleStudyJobShape.Arm(id: job.config, model: "apple-\(job.route)", flow: "apple"),
                variants: job.variants, repetition: 0
            ),
            appDraftPrompt: ScriptPromptBuilder.prompt(for: prepared),
            instructions: ScriptPromptBuilder.instructions(for: prepared)
        )
        let started = ContinuousClock.now
        for attempt in 1...3 {
            record.attempts = attempt
            do {
                let script = try await service.generate(request)
                record.title = script.title
                record.script = script.text
                record.draft = script.discardedDraft ?? ""
                record.model = script.model?.rawValue
                if script.model != route { record.outcome = "otherRoute" }
                break
            } catch ScriptAIError.rateLimited where attempt < 3 {
                try? await Task.sleep(for: Self.rateLimitPause)
            } catch {
                record.outcome = "failed"
                record.failure = "\(error)"
                break
            }
        }
        record.seconds = started.duration(to: .now).inSeconds
        record.finishedAt = Date()
        Attachment.record(try Self.encoder.encode(record), named: "\(job.id).json")
        print("AppleStudy \(job.id): \(record.outcome), \(record.model ?? "no model"), \(Int(record.seconds)) s, "
            + "\(ReadTime.wordCount(in: record.script)) words")
        try await Task.sleep(for: Self.pause)
    }
}
