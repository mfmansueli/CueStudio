//
//  ClaudeStreamReader.swift
//  Cue Studio
//

import Foundation

/// Reads Claude's answer as it streams (server-sent events in the Claude API's own shape), line by line: the answer's words (the thinking's
/// deltas stay out of the script), the token counts, the model that answered and why it stopped. The same reader serves Cue's server
/// (`CueServerUltraClient`, which passes Claude's events through unchanged) and the lab's direct calls (`AnthropicUltraClient`). An error event
/// or a refusal becomes its kind only (`UltraClientError`): no message from the provider is ever kept.
nonisolated struct ClaudeStreamReader {
    private(set) var reply = UltraModelReply(text: "", finishedNormally: false)
    private var stopReason: String?

    init(model: String? = nil) {
        reply.modelVersion = model
    }

    /// Takes one line of the stream; true when the answer's text grew.
    mutating func consume(_ line: String) throws -> Bool {
        guard line.hasPrefix("data:"), let data = line.dropFirst(5).data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        let before = reply.text.count
        try apply(event)
        return reply.text.count != before
    }

    /// The reply once the stream ended: a refusal (after Anthropic's fallback, when there was one) is `.blocked`; anything but a normal end
    /// leaves `finishedNormally` false, so a cut-off answer is never taken for a script.
    func finished() throws -> UltraModelReply {
        if stopReason == "refusal" { throw UltraClientError(failure: .blocked) }
        var reply = reply
        reply.finishedNormally = stopReason == "end_turn"
        return reply
    }

    private mutating func apply(_ event: [String: Any]) throws {
        switch event["type"] as? String {
        case "message_start":
            guard let message = event["message"] as? [String: Any] else { return }
            if let model = message["model"] as? String, !model.isEmpty { reply.modelVersion = model }
            if let usage = message["usage"] as? [String: Any] { read(usage) }
        case "content_block_delta":
            guard let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta", let text = delta["text"] as? String
            else { return }
            reply.text += text
        case "message_delta":
            if let reason = (event["delta"] as? [String: Any])?["stop_reason"] as? String { stopReason = reason }
            if let usage = event["usage"] as? [String: Any] { read(usage) }
        case "error":
            throw UltraClientError(failure: .provider)
        default:
            return
        }
    }

    /// Claude's counts: the prompt is what it read fresh plus what it read from or wrote to its cache; thinking is inside `output_tokens`.
    private mutating func read(_ usage: [String: Any]) {
        if let input = usage["input_tokens"] as? Int {
            let cached = usage["cache_read_input_tokens"] as? Int ?? 0
            let written = usage["cache_creation_input_tokens"] as? Int ?? 0
            reply.promptTokens = input + cached + written
            reply.cachedTokens = cached
        }
        if let output = usage["output_tokens"] as? Int { reply.outputTokens = output }
    }

    // MARK: - Failures

    /// A status that came back before the first word, read as Cue's server and the Claude API send it. Cue's server names its own refusals in
    /// `X-Ultra-Refusal` (`refusal`): no scripts left, the day's budget reached, too many calls this hour.
    static func failure(status: Int, refusal: String? = nil) -> UltraFailure {
        switch refusal {
        case "noCredits": return .outOfScripts
        case "paused": return .paused
        case "limited": return .limited
        default: break
        }
        return switch status {
        case 401, 403, 429: .rejected
        case 408, 504: .timedOut
        default: .provider
        }
    }

    /// The kind of failure, without the provider's message.
    static func mapped(_ error: any Error) -> any Error {
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
