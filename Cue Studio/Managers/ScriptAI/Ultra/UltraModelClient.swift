//
//  UltraModelClient.swift
//  Cue Studio
//

import Foundation

/// One call to Ultra AI's model: Claude through Cue's server in TestFlight and the App Store (`CueServerUltraClient`), and the Debug lab's
/// clients (`FirebaseUltraClient`, Claude direct). The flow is tested with a fake that never touches the network, and UI tests use a stub
/// (`StubUltraClient`).
@MainActor
protocol UltraModelClient: AnyObject, Sendable {
    /// The model's answer to `request`. `progress` hears how many words have arrived so far, while they stream.
    func generate(_ request: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void) async throws -> UltraModelReply
}
