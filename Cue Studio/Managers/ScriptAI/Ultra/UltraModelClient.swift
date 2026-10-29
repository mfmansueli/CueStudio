//
//  UltraModelClient.swift
//  Cue Studio
//

import Foundation

/// One call to Gemini. The Firebase SDK lives behind this (`FirebaseUltraClient`, Debug only for now), so the flow is tested with a fake that
/// never touches the network, and UI tests use a stub (`StubUltraClient`).
@MainActor
protocol UltraModelClient: AnyObject, Sendable {
    /// The model's answer to `request`. `progress` hears how many words have arrived so far, while they stream.
    func generate(_ request: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void) async throws -> UltraModelReply
}
