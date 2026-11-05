//
//  FakeReferralClient.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Cue's invites server in memory: the creator's status as a test sets it, the codes that join, and every call kept to check what reached it.
@MainActor
final class FakeReferralClient: ReferralClient {
    struct Offline: Error {}

    var status = ReferralStatus(code: "K7M2QX", joined: 0, activated: 0, rewarded: 0, limit: 5)
    var joinsWith: [String: ReferralJoinOutcome] = ["P4WHNB": .joined]
    var isOffline = false
    private(set) var statusCalls = 0
    private(set) var joined: [String] = []
    private(set) var activations = 0

    func status(installID: UUID) async throws -> ReferralStatus {
        statusCalls += 1
        if isOffline { throw Offline() }
        return status
    }

    func join(installID: UUID, code: String) async throws -> ReferralJoinOutcome {
        if isOffline { throw Offline() }
        joined.append(code)
        return joinsWith[code] ?? .unknown
    }

    func activate(installID: UUID) async throws {
        if isOffline { throw Offline() }
        activations += 1
    }

    /// `friends` friends' first exports counted.
    func setFriends(_ friends: Int) {
        status.joined = friends
        status.activated = friends
        status.rewarded = min(friends, status.limit)
    }
}
