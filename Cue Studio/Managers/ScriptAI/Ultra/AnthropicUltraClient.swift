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
        do {
            let (bytes, response) = try await session.bytes(for: call)
            guard let status = (response as? HTTPURLResponse)?.statusCode else { throw UltraClientError(failure: .provider) }
            guard status == 200 else { throw UltraClientError(failure: ClaudeStreamReader.failure(status: status)) }
            var reader = ClaudeStreamReader(model: model)
            for try await line in bytes.lines {
                guard try reader.consume(line) else { continue }
                progress(ReadTime.wordCount(in: reader.reply.text))
            }
            return try reader.finished()
        } catch {
            throw ClaudeStreamReader.mapped(error)
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
        if let schema = ClaudeStageShape.schema(for: request.stage) { output["format"] = ["type": "json_schema", "schema": schema] }
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
}
#endif
