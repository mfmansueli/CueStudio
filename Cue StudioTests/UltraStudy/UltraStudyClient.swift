//
//  UltraStudyClient.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Ultra's calls for the study, straight to the Claude API with the lab's key (`ClaudeLabConfiguration`), sent as Cue's server sends them
/// (`server/functions/src/claudeParams.ts`: the stage's instructions as the system prompt, its prompt as the one message, adaptive thinking,
/// the effort, the stage's JSON shape, Anthropic's refusal fallback on Opus and Sonnet, the 32,000-token cap, streamed), with the model and the
/// effort of each stage chosen by the job instead of the server's settings. The job's prompt variants are applied first (`UltraStudyPrompt`),
/// and every call is kept (`UltraStudyCall`). A rate limit or an overloaded API is waited out and tried again, up to four tries, so a busy API
/// is never measured as a weaker model.
@MainActor
final class UltraStudyClient: UltraModelClient {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")
    /// What `@anthropic-ai/sdk` 1.4.0 (the server's) sends.
    static let apiVersion = "2026-10-21"
    static let fallbackBeta = "server-side-fallback-2026-07-01"
    static let responseTokens = 32_000
    static let tries = 4

    struct Failure: Error, CustomStringConvertible {
        let kind: String
        var description: String { kind }
    }

    let config: UltraStudyJob.Config
    let prompt: UltraStudyPrompt
    /// A fit goes out only for a script past this many words (the study's longer ranges, where the app's two-minute ceiling would cut a script
    /// inside its own range); nil follows the app.
    let fitAbove: Int?
    private(set) var calls: [UltraStudyCall] = []
    private var lastScriptWords = 0
    private let key: String
    private let session: URLSession

    init(config: UltraStudyJob.Config, prompt: UltraStudyPrompt, fitAbove: Int?, key: String) {
        self.config = config
        self.prompt = prompt
        self.fitAbove = fitAbove
        self.key = key
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 400
        session = URLSession(configuration: configuration)
    }

    func generate(_ request: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void) async throws -> UltraModelReply {
        let request = try prompt.applied(to: request)
        let effort = effort(for: request.stage)
        var call = UltraStudyCall(
            stage: request.stage.rawValue, model: config.model, effort: effort, instructions: request.instructions, prompt: request.prompt
        )
        if request.stage == .fit, let fitAbove, lastScriptWords <= fitAbove {
            call.outcome = "skipped"
            calls.append(call)
            throw Failure(kind: "fit skipped")
        }
        let start = ContinuousClock.now
        defer { calls.append(call) }
        do {
            let reply = try await withTries(&call) { try await self.send(request, effort: effort) }
            call.seconds = Self.seconds(since: start)
            call.text = reply.text
            call.finishedNormally = reply.finishedNormally
            call.modelVersion = reply.modelVersion
            call.inputTokens = reply.promptTokens
            call.cacheReadTokens = reply.cachedTokens
            call.outputTokens = reply.outputTokens
            if request.stage == .review, let script = UltraReviewReply(json: reply.text)?.script {
                lastScriptWords = ReadTime.wordCount(in: script)
            }
            return reply
        } catch {
            call.seconds = Self.seconds(since: start)
            call.outcome = (error as? UltraClientError).map { "\($0.failure)" } ?? String(describing: error)
            throw error
        }
    }

    private func effort(for stage: UltraStageRequest.Stage) -> String {
        switch stage {
        case .draft: config.draft
        case .check: config.check
        case .review, .fit, .ideas: config.review
        }
    }

    /// Tries `send` again after a rate limit, an overloaded API or a dropped connection: 15, 45 and 90 seconds apart.
    private func withTries(_ call: inout UltraStudyCall, _ send: () async throws -> UltraModelReply) async throws -> UltraModelReply {
        var last: (any Error)?
        for attempt in 1...Self.tries {
            call.attempts = attempt
            do {
                return try await send()
            } catch let error as RetryableStatus {
                last = UltraClientError(failure: ClaudeStreamReader.failure(status: error.status))
            } catch let error as UltraClientError where error.failure == .provider || error.failure == .timedOut || error.failure == .unreachable {
                last = error
            }
            if attempt < Self.tries { try await Task.sleep(for: .seconds([15, 45, 90][attempt - 1])) }
        }
        throw last ?? UltraClientError(failure: .provider)
    }

    private struct RetryableStatus: Error {
        let status: Int
    }

    // MARK: - The request

    private func send(_ request: UltraStageRequest, effort: String) async throws -> UltraModelReply {
        guard let endpoint = Self.endpoint else { throw UltraClientError(failure: .provider) }
        var call = URLRequest(url: endpoint)
        call.httpMethod = "POST"
        call.timeoutInterval = 280
        call.setValue("application/json", forHTTPHeaderField: "content-type")
        call.setValue(key, forHTTPHeaderField: "x-api-key")
        call.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        call.setValue(Self.fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        call.httpBody = try JSONSerialization.data(withJSONObject: body(for: request, effort: effort))
        do {
            let (bytes, response) = try await session.bytes(for: call)
            guard let status = (response as? HTTPURLResponse)?.statusCode else { throw UltraClientError(failure: .provider) }
            if [408, 429, 500, 502, 503, 504, 529].contains(status) { throw RetryableStatus(status: status) }
            // Any other status (a malformed request, a revoked key) is not tried again, and is kept by its number.
            guard status == 200 else { throw Failure(kind: "status \(status)") }
            var reader = ClaudeStreamReader(model: config.model)
            for try await line in bytes.lines { _ = try reader.consume(line) }
            return try reader.finished()
        } catch let error as RetryableStatus {
            throw error
        } catch let error as Failure {
            throw error
        } catch {
            throw ClaudeStreamReader.mapped(error)
        }
    }

    /// `claudeParams` of the server, with the job's model and the stage's effort.
    private func body(for request: UltraStageRequest, effort: String) -> [String: Any] {
        var output: [String: Any] = ["effort": effort]
        if let schema = ClaudeStageShape.schema(for: request.stage) { output["format"] = ["type": "json_schema", "schema": schema] }
        var body: [String: Any] = [
            "model": config.model,
            "max_tokens": Self.responseTokens,
            "stream": true,
            "system": request.instructions,
            "messages": [["role": "user", "content": request.prompt]],
            "thinking": ["type": "adaptive"],
            "output_config": output,
        ]
        // Haiku has no server-side fallback (`ultraModels` in the server).
        if !config.model.contains("haiku") { body["fallbacks"] = "default" }
        return body
    }

    private static func seconds(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: .now)
        return Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
