//
//  CueServerUltraClient.swift
//  Cue Studio
//

import Foundation

/// One Ultra AI call through Cue's own server (`server/functions`, the `ultra` function in the Firebase project `cuestudio-app`), which holds
/// the Claude API key, picks the model and the effort and passes Claude's answer back as it streams. The app sends only what "What Cue sends"
/// shows (the stage's instructions and prompt), the JSON shape the stage answers in, a lower effort when the flow asks for one, and an App Check
/// token proving the request comes from Cue on a real iPhone (App Attest; a registered debug token in a Debug build). The shipped Ultra AI's
/// only client: no key is ever in the app. Errors come back as their kind only (`UltraClientError`).
@MainActor
final class CueServerUltraClient: UltraModelClient {
    static let endpoint = URL(string: "https://us-central1-cuestudio-app.cloudfunctions.net/ultra")
    /// A polished script took 25–40 s with Claude in the lab; the server gives up on Claude at 280 s.
    static let timeout: TimeInterval = 180
    /// The model the server said last answered, for pricing what it spent (`UltraPrice.current`).
    nonisolated static let lastModelKey = "ultra.server.lastModel"

    private let endpoint: URL?
    private let appCheckToken: @MainActor () async throws -> String
    private let session: URLSession
    private let defaults: UserDefaults

    init(
        endpoint: URL? = CueServerUltraClient.endpoint, defaults: UserDefaults = .standard,
        appCheckToken: @escaping @MainActor () async throws -> String = { try await UltraAppCheck.token() }
    ) {
        self.endpoint = endpoint
        self.appCheckToken = appCheckToken
        self.defaults = defaults
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = Self.timeout + 20
        session = URLSession(configuration: configuration)
    }

    /// The client, when Firebase runs in this launch (App Check needs it); nil in tests and previews, where nothing reaches the network.
    static func make() -> CueServerUltraClient? {
        UltraAppCheck.isReady ? CueServerUltraClient() : nil
    }

    func generate(_ request: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void) async throws -> UltraModelReply {
        // The library's ideas are a developer tool's, written with the lab's own access, never through the creators' server.
        guard request.stage != .ideas, let endpoint else { throw UltraClientError(failure: .rejected) }
        let token: String
        do {
            token = try await appCheckToken()
        } catch let error as URLError {
            throw ClaudeStreamReader.mapped(error)
        } catch {
            // No App Check token (Firebase isn't running, or the iPhone couldn't prove it is Cue): the server would refuse the call anyway.
            throw UltraClientError(failure: .rejected)
        }
        do {
            var call = URLRequest(url: endpoint)
            call.httpMethod = "POST"
            call.timeoutInterval = Self.timeout
            call.setValue("application/json", forHTTPHeaderField: "Content-Type")
            call.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
            call.httpBody = try JSONSerialization.data(withJSONObject: Self.body(for: request))
            let (bytes, response) = try await session.bytes(for: call)
            guard let status = (response as? HTTPURLResponse)?.statusCode else { throw UltraClientError(failure: .provider) }
            guard status == 200 else { throw UltraClientError(failure: ClaudeStreamReader.failure(status: status)) }
            var reader = ClaudeStreamReader()
            for try await line in bytes.lines {
                guard try reader.consume(line) else { continue }
                progress(ReadTime.wordCount(in: reader.reply.text))
            }
            let reply = try reader.finished()
            if let model = reply.modelVersion { defaults.set(model, forKey: Self.lastModelKey) }
            return reply
        } catch {
            throw ClaudeStreamReader.mapped(error)
        }
    }

    /// What goes to the server: the stage, its instructions and prompt as written, its JSON shape, and an effort only when the flow asks for a
    /// lower one (`UltraThinking`); otherwise the server's own (`ULTRA_EFFORT`).
    nonisolated static func body(for request: UltraStageRequest) -> [String: Any] {
        var body: [String: Any] = ["stage": request.stage.rawValue, "system": request.instructions, "prompt": request.prompt]
        if let schema = ClaudeStageShape.schema(for: request.stage) { body["schema"] = schema }
        switch request.thinking.level(for: request.stage) {
        case nil: break
        case .medium: body["effort"] = "medium"
        case .low: body["effort"] = "low"
        }
        return body
    }
}
