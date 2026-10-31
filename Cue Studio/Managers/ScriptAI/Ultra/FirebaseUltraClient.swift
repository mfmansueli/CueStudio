//
//  FirebaseUltraClient.swift
//  Cue Studio
//

#if DEBUG
import FirebaseAILogic
import FirebaseAppCheck
import FirebaseCore
import Foundation

/// The only place that talks to Firebase AI Logic: the Agent Platform Gemini API (formerly Vertex AI) at the `global` location, through the lab's
/// own Firebase app (`UltraLabConfiguration`), with App Check. One request per call: no retry, no other model, no fallback to the Gemini Developer
/// API. Errors come back as their kind only (`UltraClientError`); the provider's message, which can quote the request, is never kept.
/// Debug builds only, while Ultra is an experiment.
@MainActor
final class FirebaseUltraClient: UltraModelClient {
    /// The model asked for; the provider may report another version (`UltraModelReply.modelVersion`).
    static let modelName = "gemini-3.5-flash"
    static let location = "global"
    /// A polished script took 20–25 s in the web lab; one call never waits more than this.
    static let timeout: TimeInterval = 120

    private let ai: FirebaseAI

    private init(ai: FirebaseAI) {
        self.ai = ai
    }

    /// The client, when the lab's configuration is on this iPhone and is the lab's (project and bundle checked); nil otherwise. Called only when the
    /// first permitted script is written (`UltraScriptService`): configuring the lab's Firebase app earlier would let App Check talk to Google first.
    static func make() -> FirebaseUltraClient? {
        let path = UltraLabConfiguration.fileURL.path
        guard FileManager.default.fileExists(atPath: path), let options = FirebaseOptions(contentsOfFile: path),
              UltraLabConfiguration.accepts(projectID: options.projectID, bundleID: options.bundleID, appBundleID: Bundle.main.bundleIdentifier)
        else { return nil }
        if FirebaseApp.app(name: UltraLabConfiguration.appName) == nil {
            // The registered debug token, when it was copied over: App Check's debug provider reads it from here.
            if let token = UltraLabConfiguration.debugToken() {
                UserDefaults.standard.set(token, forKey: UltraLabConfiguration.debugTokenDefaultsKey)
            }
            AppCheck.setAppCheckProviderFactory(UltraLabAppCheckFactory())
            FirebaseApp.configure(name: UltraLabConfiguration.appName, options: options)
        }
        guard let app = FirebaseApp.app(name: UltraLabConfiguration.appName) else { return nil }
        // No app id or version headers beyond what a call needs, and App Check asks for a token only when a call does.
        app.isDataCollectionDefaultEnabled = false
        AppCheck.appCheck(app: app)?.isTokenAutoRefreshEnabled = false
        return FirebaseUltraClient(ai: FirebaseAI.firebaseAI(app: app, backend: .agentPlatform(location: location)))
    }

    func generate(_ request: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void) async throws -> UltraModelReply {
        let model = ai.generativeModel(
            modelName: Self.modelName, generationConfig: Self.configuration(for: request.stage, thinking: request.thinking),
            systemInstruction: ModelContent(role: "system", parts: request.instructions), requestOptions: RequestOptions(timeout: Self.timeout)
        )
        var reply = UltraModelReply(text: "", finishedNormally: false)
        do {
            for try await chunk in try model.generateContentStream(request.prompt) {
                if let candidate = chunk.candidates.first {
                    let text = candidate.content.parts.compactMap { part -> String? in
                        guard let text = part as? TextPart, !text.isThought else { return nil }
                        return text.text
                    }.joined()
                    if !text.isEmpty {
                        reply.text += text
                        progress(ReadTime.wordCount(in: reply.text))
                    }
                    if let reason = candidate.finishReason { reply.finishedNormally = reason == .stop }
                }
                if let usage = chunk.usageMetadata {
                    reply.promptTokens = usage.promptTokenCount
                    reply.cachedTokens = usage.cachedContentTokenCount
                    reply.outputTokens = usage.candidatesTokenCount
                    reply.thinkingTokens = usage.thoughtsTokenCount
                }
                if !chunk.modelVersion.isEmpty { reply.modelVersion = chunk.modelVersion }
            }
        } catch {
            throw Self.mapped(error)
        }
        return reply
    }

    // MARK: - Configuration

    private static func configuration(for stage: UltraStageRequest.Stage, thinking: UltraThinking) -> GenerationConfig {
        let tokens = UltraStageRequest.responseTokens
        let thinkingConfig = config(for: thinking.level(for: stage))
        return switch stage {
        case .draft:
            GenerationConfig(maxOutputTokens: tokens, thinkingConfig: thinkingConfig)
        case .check:
            GenerationConfig(maxOutputTokens: tokens, responseMIMEType: "application/json", responseSchema: checkSchema, thinkingConfig: thinkingConfig)
        case .review:
            GenerationConfig(maxOutputTokens: tokens, responseMIMEType: "application/json", responseSchema: reviewSchema, thinkingConfig: thinkingConfig)
        case .fit:
            GenerationConfig(maxOutputTokens: tokens, responseMIMEType: "application/json", responseSchema: fitSchema, thinkingConfig: thinkingConfig)
        }
    }

    /// Nothing for the model's own choice, so today's requests stay exactly as they were.
    private static func config(for level: UltraThinking.Level?) -> ThinkingConfig? {
        switch level {
        case nil: nil
        case .medium: ThinkingConfig(thinkingLevel: .medium)
        case .low: ThinkingConfig(thinkingLevel: .low)
        }
    }

    /// `UltraCheckReply`'s two keys.
    private static let checkSchema = Schema.object(properties: [
        "script": .string(),
        "corrections": .array(items: .string()),
    ])

    /// `UltraFitReply`'s one key.
    private static let fitSchema = Schema.object(properties: ["script": .string()])

    /// `UltraReviewReply`'s three keys.
    private static let reviewSchema = Schema.object(properties: [
        "title": .string(),
        "script": .string(),
        "changes": .array(items: .string()),
    ])

    // MARK: - Errors

    /// The kind of failure, without the provider's message.
    private static func mapped(_ error: any Error) -> any Error {
        if error is CancellationError { return error }
        if let error = error as? URLError {
            switch error.code {
            case .cancelled: return CancellationError()
            case .timedOut: return UltraClientError(failure: .timedOut)
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed:
                return UltraClientError(failure: .unreachable)
            default: return UltraClientError(failure: .provider)
            }
        }
        if let error = error as? GenerateContentError {
            switch error {
            case .promptBlocked: return UltraClientError(failure: .blocked)
            case .responseStoppedEarly(let reason, _):
                return UltraClientError(failure: [.safety, .blocklist, .prohibitedContent, .spii].contains(reason) ? .blocked : .incomplete)
            case .internalError(let underlying): return mapped(underlying)
            default: return UltraClientError(failure: .provider)
            }
        }
        // The SDK's backend errors are NSErrors whose code is the HTTP status.
        let nsError = error as NSError
        if nsError.domain.hasSuffix("BackendError") {
            switch nsError.code {
            case 401, 403, 429: return UltraClientError(failure: .rejected)
            case 408, 504: return UltraClientError(failure: .timedOut)
            default: return UltraClientError(failure: .provider)
            }
        }
        return UltraClientError(failure: .provider)
    }
}
#endif
