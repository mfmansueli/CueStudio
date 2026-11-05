//
//  CueServerReferralClient.swift
//  Cue Studio
//

import Foundation

/// The invites through Cue's own server (`server/functions`, the `referral` function in the Firebase project `cuestudio-app`). Each request
/// carries an App Check token (App Attest on a real iPhone; a registered debug token in a Debug build) and the install's random id; joining
/// also carries the code the friend typed. Nothing else: no name, no account, no contacts.
@MainActor
final class CueServerReferralClient: ReferralClient {
    struct Failure: Error {}

    static let endpoint = URL(string: "https://us-central1-cuestudio-app.cloudfunctions.net/referral")
    static let timeout: TimeInterval = 15

    private let endpoint: URL?
    private let appCheckToken: @MainActor () async throws -> String
    private let session: URLSession

    init(
        endpoint: URL? = CueServerReferralClient.endpoint,
        appCheckToken: @escaping @MainActor () async throws -> String = { try await UltraAppCheck.token() }
    ) {
        self.endpoint = endpoint
        self.appCheckToken = appCheckToken
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Self.timeout
        session = URLSession(configuration: configuration)
    }

    /// The client, when Firebase runs in this launch (App Check needs it); nil in tests and previews, where nothing reaches the network.
    static func make() -> CueServerReferralClient? {
        UltraAppCheck.isReady ? CueServerReferralClient() : nil
    }

    func status(installID: UUID, proof: String?) async throws -> ReferralStatus {
        var body = ["action": "status", "installId": installID.uuidString]
        if let proof { body["proof"] = proof }
        return try JSONDecoder().decode(ReferralStatus.self, from: try await call(body))
    }

    func join(installID: UUID, code: String) async throws -> ReferralJoinOutcome {
        let data = try await call(["action": "redeem", "installId": installID.uuidString, "code": code])
        return try JSONDecoder().decode(Answer.self, from: data).outcome
    }

    func activate(installID: UUID) async throws {
        _ = try await call(["action": "activate", "installId": installID.uuidString])
    }

    private struct Answer: Decodable {
        let outcome: ReferralJoinOutcome
    }

    private func call(_ body: [String: String]) async throws -> Data {
        guard let endpoint else { throw Failure() }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(try await appCheckToken(), forHTTPHeaderField: "X-Firebase-AppCheck")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure() }
        return data
    }
}
