//
//  UltraLabClient.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Ultra AI's client in a Debug build: each call goes to the provider picked in the lab (`UltraLabProvider`; Cue's server unless another was
/// picked), so the server, Gemini and Claude can be compared on the same iPhone without relaunching. A provider that isn't set up on this iPhone
/// refuses the call (`UltraFailure.rejected`).
@MainActor
final class UltraLabClient: UltraModelClient, UltraAllowanceReporting {
    private var server: CueServerUltraClient?
    private var google: FirebaseUltraClient?
    private var claude: [String: AnthropicUltraClient] = [:]

    /// Ultra is offered in this Debug launch: Firebase runs (so Cue's server can be reached) or the lab's Gemini or Claude is set up here.
    static var isOffered: Bool {
        UltraAppCheck.isReady || UltraLabConfiguration.isPresent || ClaudeLabConfiguration.isPresent
    }

    func generate(_ request: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void) async throws -> UltraModelReply {
        let provider = UltraLabProvider.selected
        if provider == .cueServer {
            guard let client = server ?? CueServerUltraClient.make() else { throw UltraClientError(failure: .rejected) }
            server = client
            return try await client.generate(request, progress: progress)
        }
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

    /// The server's count when the lab writes through Cue's server; another provider counts nothing on a server.
    func allowance(for caller: UltraCaller) async throws -> UltraServerAllowance {
        guard UltraLabProvider.selected == .cueServer else { return UltraServerAllowance(metering: "off") }
        guard let client = server ?? CueServerUltraClient.make() else { throw UltraClientError(failure: .rejected) }
        server = client
        return try await client.allowance(for: caller)
    }
}
#endif
