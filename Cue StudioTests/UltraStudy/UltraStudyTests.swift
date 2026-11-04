//
//  UltraStudyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The owner's study of Ultra AI (04/11/2026): which model and effort write well enough for less, whether the formats reach the model,
/// longer lengths, and why titles drift. Writes each job of `<CUE_ULTRA_STUDY>/jobs.json` (`tools/ultra/study/jobs.py`) through the app's own
/// `UltraScriptService` and `UltraPayload`, with the study's client (`UltraStudyClient`: Claude as Cue's server calls it, the job's model and
/// effort per stage, the job's prompt variants), and saves each result as `out/<job id>.json` (`UltraStudyRecord`). A job already saved is
/// not written again, so a run that stops is resumed by running it again (`UltraStudyFolder`).
///
/// Runs on the Simulator with the lab's Claude key in the test host's Documents (`ClaudeLabConfiguration`), and spends real credits:
///
///     TEST_RUNNER_CUE_ULTRA_STUDY=<folder outside the Desktop> scripts/test.sh only "Cue StudioTests/UltraStudyTests"
///
/// Skipped unless the folder is set. Synthetic creators only (`UltraStudyCreators`).
@Suite(.serialized, .enabled(if: UltraStudyFolder.url != nil))
@MainActor
struct UltraStudyTests {
    @Test(.timeLimit(.minutes(9)), arguments: UltraStudyFolder.batches)
    func writes(batch: Int) async throws {
        let key = try #require(ClaudeLabConfiguration.apiKey(), "Copy the lab's Claude key into the test host's Documents first")
        // The batch's jobs side by side, on the main actor like the app's service (each waits on the network, not on the others).
        let writing = UltraStudyFolder.jobs(in: batch).map { job in Task { await Self.write(job, key: key) } }
        for job in writing { await job.value }
    }

    // MARK: - One job

    private static func write(_ job: UltraStudyJob, key: String) async {
        let start = ContinuousClock.now
        var record = UltraStudyRecord(job: job, appDraftPrompt: "")
        var apiFailed = false
        do {
            let request = try job.request()
            record = UltraStudyRecord(job: job, appDraftPrompt: UltraPayload(request, length: job.lengthOverride).draft.prompt)
            let prompt = UltraStudyPrompt(
                variants: job.variants, format: try job.formatChoice, angle: job.item.brief.flatMap { IdeaAngle(rawValue: $0.angleKind) }
            )
            let client = UltraStudyClient(config: job.config, prompt: prompt, fitAbove: fitAbove(job, request: request), key: key)
            let defaults = TestDefaults()
            defer { defaults.tearDown() }
            let consent = UltraConsentService(defaults: defaults.defaults)
            // Synthetic data only: this permission is the test's, in its own defaults.
            consent.grant()
            let service = UltraScriptService(client: client, consent: consent, budget: UltraCallBudget(defaults: defaults.defaults, limit: 50))
            do {
                let run = try await service.run(request, length: job.lengthOverride, flow: UltraFlow(rawValue: job.config.flow))
                record.title = run.script.title
                record.script = run.script.text
                record.draft = run.draft
                record.checked = run.checked
                record.corrections = run.corrections
                record.changes = run.changes
                if client.calls.contains(where: { $0.stage == "fit" && $0.outcome == "ok" }) {
                    record.beforeFit = UltraReviewReply(json: run.reviewReply.text)?.script
                }
            } catch {
                record.outcome = "failed: \(error)"
                // A failure the model caused (a cut-off answer, a refusal) is a result; one the API caused is written again next run.
                apiFailed = client.calls.contains { $0.outcome != "ok" && $0.outcome != "skipped" && $0.outcome != "blocked" }
            }
            record.calls = client.calls
        } catch {
            record.outcome = "invalid: \(error)"
            apiFailed = true
        }
        let duration = start.duration(to: .now)
        record.seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        record.finishedAt = Date()
        save(record, to: apiFailed ? UltraStudyFolder.failure(for: job) : UltraStudyFolder.output(for: job))
    }

    /// Past the study's own longer ranges, the app's two-minute ceiling would cut a script inside its range: there a fit goes out only past
    /// 15% over the range's top (the app's own margin). Nil keeps the app's rule.
    private static func fitAbove(_ job: UltraStudyJob, request: ScriptRequest) -> Int? {
        guard let length = job.length, length.kind == "ideal", let high = length.high,
              high * 1.15 > ScriptRequestFactory.autoCeiling else { return nil }
        return ReadTime.words(for: high * 1.15, language: request.language)
    }

    // MARK: - Files

    private static func save(_ record: UltraStudyRecord, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(record).write(to: url, options: .atomic)
        } catch {
            Issue.record("Couldn't save \(record.job.id): \(error)")
        }
    }
}
