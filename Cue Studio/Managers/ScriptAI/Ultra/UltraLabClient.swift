//
//  UltraLabClient.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Ultra AI's client in a Debug build: each call goes to the provider picked in the lab (`UltraLabProvider`), so Gemini and Claude can be
/// compared on the same iPhone without relaunching. A provider that isn't set up on this iPhone refuses the call (`UltraFailure.rejected`).
@MainActor
final class UltraLabClient: UltraModelClient {
    private var google: FirebaseUltraClient?
    private var claude: [String: AnthropicUltraClient] = [:]

    /// The client, when at least one provider is set up on this iPhone.
    static func make() -> UltraLabClient? {
        UltraLabConfiguration.isPresent || ClaudeLabConfiguration.isPresent ? UltraLabClient() : nil
    }

    func generate(_ request: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void) async throws -> UltraModelReply {
        let provider = UltraLabProvider.selected
        if let model = provider.claudeModel {
            guard let key = ClaudeLabConfiguration.apiKey() else { throw UltraClientError(failure: .rejected) }
            let client = claude[model] ?? AnthropicUltraClient(model: model, key: key, refusalFallback: provider.refusalFallback)
            claude[model] = client
            return try await client.generate(request, progress: progress)
        }
        guard let client = google ?? FirebaseUltraClient.make() else { throw UltraClientError(failure: .rejected) }
        google = client
        return try await client.generate(request, progress: progress)
    }
}
#endif
