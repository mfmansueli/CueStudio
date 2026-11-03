//
//  AnthropicUltraClient.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// One Ultra AI call to Claude, straight to the Claude API with the lab's key (`ClaudeLabConfiguration`), for the owner's comparison with Gemini
/// (02/11/2026). It sends what `FirebaseUltraClient` sends (the stage's instructions as the system prompt, its prompt as the one message, the
/// same JSON shapes as structured outputs) and streams the answer, so the words arrive as they do with Google. Adaptive thinking is always on;
/// `UltraThinking.model` asks for the lab's effort (`UltraLabEffort`, high unless picked lower), a lower `UltraThinking` for `medium` or `low`.
/// On Opus and Sonnet a policy refusal is re-run on Anthropic's recommended model (`fallbacks: "default"`; Haiku has none). One request per
/// call, no retry. Errors come back as their kind only
/// (`UltraClientError`); the API's message, which can quote the request, is never kept. Debug builds only: the shipped Ultra AI will reach
/// Claude through Cue's server, never with a key in the app.
@MainActor
final class AnthropicUltraClient: UltraModelClient {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")
    static let apiVersion = "2026-10-21"
    static let fallbackBeta = "server-side-fallback-2026-07-01"
    /// The most a call may answer, thinking included: Claude's thinking counts against it, so it is well above Gemini's 8,192.
    static let responseTokens = 32_000
    static let ideaResponseTokens = 64_000
    static let timeout: TimeInterval = 180
    static let ideasTimeout: TimeInterval = 400

    let model: String
    private let key: String
    private let refusalFallback: Bool
    private let session: URLSession

    init(model: String, key: String, refusalFallback: Bool) {
        self.model = model
        self.key = key
        self.refusalFallback = refusalFallback
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = Self.ideasTimeout
        session = URLSession(configuration: configuration)
    }

    func generate(_ request: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void) async throws -> UltraModelReply {
        let call = try urlRequest(for: request)
        var reply = UltraModelReply(text: "", finishedNormally: false)
        reply.modelVersion = model
        do {
            let (bytes, response) = try await session.bytes(for: call)
            guard let status = (response as? HTTPURLResponse)?.statusCode else { throw UltraClientError(failure: .provider) }
            guard status == 200 else { throw UltraClientError(failure: Self.failure(status: status)) }
            var stopReason: String?
            for try await line in bytes.lines {
                guard line.hasPrefix("data:"), let data = line.dropFirst(5).data(using: .utf8),
                      let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                let before = reply.text.count
                try Self.apply(event, to: &reply, stopReason: &stopReason)
                if reply.text.count != before { progress(ReadTime.wordCount(in: reply.text)) }
            }
            if stopReason == "refusal" { throw UltraClientError(failure: .blocked) }
            reply.finishedNormally = stopReason == "end_turn"
        } catch {
            throw Self.mapped(error)
        }
        return reply
    }

    /// One event of the stream: the usage it reports, the answer's words (the thinking's deltas stay out of the script), why it stopped.
    private static func apply(_ event: [String: Any], to reply: inout UltraModelReply, stopReason: inout String?) throws {
        switch event["type"] as? String {
        case "message_start":
            if let usage = (event["message"] as? [String: Any])?["usage"] as? [String: Any] { read(usage, into: &reply) }
        case "content_block_delta":
            guard let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta", let text = delta["text"] as? String
            else { return }
            reply.text += text
        case "message_delta":
            if let reason = (event["delta"] as? [String: Any])?["stop_reason"] as? String { stopReason = reason }
            if let usage = event["usage"] as? [String: Any] { read(usage, into: &reply) }
        case "error":
            throw UltraClientError(failure: .provider)
        default:
            return
        }
    }

    // MARK: - The request

    private func urlRequest(for request: UltraStageRequest) throws -> URLRequest {
        guard let endpoint = Self.endpoint else { throw UltraClientError(failure: .provider) }
        var call = URLRequest(url: endpoint)
        call.httpMethod = "POST"
        call.timeoutInterval = request.stage == .ideas ? Self.ideasTimeout : Self.timeout
        call.setValue("application/json", forHTTPHeaderField: "content-type")
        call.setValue(key, forHTTPHeaderField: "x-api-key")
        call.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        if refusalFallback { call.setValue(Self.fallbackBeta, forHTTPHeaderField: "anthropic-beta") }
        call.httpBody = try JSONSerialization.data(withJSONObject: body(for: request))
        return call
    }

    private func body(for request: UltraStageRequest) -> [String: Any] {
        var output: [String: Any] = ["effort": Self.effort(for: request.thinking.level(for: request.stage))]
        if let schema = Self.schema(for: request.stage) { output["format"] = ["type": "json_schema", "schema": schema] }
        var body: [String: Any] = [
            "model": model,
            "max_tokens": request.stage == .ideas ? Self.ideaResponseTokens : Self.responseTokens,
            "stream": true,
            "system": request.instructions,
            "messages": [["role": "user", "content": request.prompt]],
            "output_config": output,
        ]
        if refusalFallback { body["fallbacks"] = "default" }
        return body
    }

    private static func effort(for level: UltraThinking.Level?) -> String {
        switch level {
        case nil: UltraLabEffort.selected.rawValue
        case .medium: "medium"
        case .low: "low"
        }
    }

    /// The same shapes `FirebaseUltraClient` asks Gemini for, every key required.
    private static func schema(for stage: UltraStageRequest.Stage) -> [String: Any]? {
        switch stage {
        case .draft: nil
        case .check: object(["script": string, "corrections": array(of: string)])
        case .review: object(["title": string, "script": string, "changes": array(of: string)])
        case .fit: object(["script": string])
        case .ideas: object(["ideas": array(of: idea)])
        }
    }

    /// One of the library's ideas, with its topic's number and its angle's key.
    private static let idea = object([
        "topic": ["type": "integer"], "angle": string, "title": string, "pointOfView": string, "openingLine": string,
    ])

    private static let string: [String: Any] = ["type": "string"]

    private static func array(of items: [String: Any]) -> [String: Any] {
        ["type": "array", "items": items]
    }

    private static func object(_ properties: [String: [String: Any]]) -> [String: Any] {
        ["type": "object", "properties": properties, "required": properties.keys.sorted(), "additionalProperties": false]
    }

    // MARK: - The answer

    /// Claude's counts: the prompt is what it read fresh plus what it read from or wrote to its cache; thinking is inside `output_tokens`.
    private static func read(_ usage: [String: Any], into reply: inout UltraModelReply) {
        if let input = usage["input_tokens"] as? Int {
            let cached = usage["cache_read_input_tokens"] as? Int ?? 0
            let written = usage["cache_creation_input_tokens"] as? Int ?? 0
            reply.promptTokens = input + cached + written
            reply.cachedTokens = cached
        }
        if let output = usage["output_tokens"] as? Int { reply.outputTokens = output }
    }

    // MARK: - Errors

    private static func failure(status: Int) -> UltraFailure {
        switch status {
        case 401, 403, 429: .rejected
        case 408, 504: .timedOut
        default: .provider
        }
    }

    /// The kind of failure, without the API's message.
    private static func mapped(_ error: any Error) -> any Error {
        if error is CancellationError || error is UltraClientError { return error }
        if let error = error as? URLError {
            switch error.code {
            case .cancelled: return CancellationError()
            case .timedOut: return UltraClientError(failure: .timedOut)
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed:
                return UltraClientError(failure: .unreachable)
            default: return UltraClientError(failure: .provider)
            }
        }
        return UltraClientError(failure: .provider)
    }
}
#endif
