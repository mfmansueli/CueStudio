//
//  FakeNotificationCenter.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// The system's notification center, in memory: what permission it holds, what asking answers, the requests it was given, and a way to make
/// `add` fail. Nothing is ever delivered or shown.
@MainActor
final class FakeNotificationCenter: NotificationCenterClient {
    struct Refused: Error {}

    var status: NotificationAuthorization
    /// What the creator answers when Cue asks.
    var allowsWhenAsked = true
    var failsToAdd = false
    private(set) var requests: [String: LocalNotificationRequest] = [:]
    private(set) var requestCount = 0
    private(set) var addCount = 0
    private(set) var removedDelivered: [String] = []

    init(status: NotificationAuthorization = .authorized) {
        self.status = status
    }

    func authorization() async -> NotificationAuthorization { status }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        guard status == .notDetermined else { return status.canSchedule }
        status = allowsWhenAsked ? .authorized : .denied
        return allowsWhenAsked
    }

    func add(_ request: LocalNotificationRequest) async throws {
        if failsToAdd { throw Refused() }
        addCount += 1
        requests[request.identifier] = request
    }

    func pendingIdentifiers() async -> [String] { Array(requests.keys) }

    func removePending(_ identifiers: [String]) {
        for identifier in identifiers { requests[identifier] = nil }
    }

    func removeDelivered(_ identifiers: [String]) {
        removedDelivered += identifiers
    }

    func requests(of campaign: NotificationCampaign) -> [LocalNotificationRequest] {
        requests.values.filter { $0.payload.campaign == campaign }
    }
}
