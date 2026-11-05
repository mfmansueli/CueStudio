//
//  StubReferralClient.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Cue's invites server for UI tests (`-uiTestReferral`): the creator's code is K7M2QX, `friends` friends already exported their first video,
/// a friend's code that counts is P4WHNB, and every other well-formed code is unknown. Nothing reaches the network.
@MainActor
final class StubReferralClient: ReferralClient {
    static let code = "K7M2QX"
    static let friendCode = "P4WHNB"

    private let friends: Int

    init(friends: Int = 0) {
        self.friends = friends
    }

    func status(installID: UUID) async throws -> ReferralStatus {
        ReferralStatus(code: Self.code, joined: friends, activated: friends, rewarded: min(friends, 5), limit: 5)
    }

    func join(installID: UUID, code: String) async throws -> ReferralJoinOutcome {
        code == Self.friendCode ? .joined : .unknown
    }

    func activate(installID: UUID) async throws {}
}
#endif
