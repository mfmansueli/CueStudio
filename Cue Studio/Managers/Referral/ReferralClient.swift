//
//  ReferralClient.swift
//  Cue Studio
//

import Foundation

/// Cue's server for the invites (`CueServerReferralClient`; a stub in the UI tests). Each call names the install by its random id only.
protocol ReferralClient: AnyObject, Sendable {
    /// The creator's code (made on the first call) and their invites. `proof`: on Cue Pro where Ultra AI is offered, the App Store's signed
    /// transaction, so the server credits new friends as Ultra AI scripts.
    func status(installID: UUID, proof: String?) async throws -> ReferralStatus
    /// A friend typed a code before their first export.
    func join(installID: UUID, code: String) async throws -> ReferralJoinOutcome
    /// The friend exported their first video.
    func activate(installID: UUID) async throws
}
