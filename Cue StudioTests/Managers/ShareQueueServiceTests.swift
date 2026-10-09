//
//  ShareQueueServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The queues that are not finished: kept across launches, one per video, gone once every network is posted.
@MainActor
@Suite("ShareQueueService")
struct ShareQueueServiceTests {
    private func make() -> (ShareQueueService, TestDefaults) {
        let defaults = TestDefaults()
        return (ShareQueueService(defaults: defaults.defaults), defaults)
    }

    @Test func aQueueSurvivesARelaunch() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        let take = UUID()
        service.begin(takeID: take, operationID: UUID(), title: "3 habits", networks: [.tiktok, .reels])
        service.markPosted(takeID: take, network: .tiktok)
        let again = ShareQueueService(defaults: defaults.defaults)
        #expect(again.queue(forTake: take)?.posted == [.tiktok])
        #expect(again.pending?.current?.network == .reels)
    }

    @Test func aQueueRemembersWhenItLastMovedForTheNotifications() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        var now = TestData.now
        let service = ShareQueueService(defaults: defaults.defaults, now: { now })
        let take = UUID()
        service.begin(takeID: take, operationID: UUID(), title: "A", networks: [.tiktok, .reels])
        #expect(service.queue(forTake: take)?.updatedAt == TestData.now)
        now += 3600
        service.postLater(takeID: take, network: .tiktok)
        #expect(service.queue(forTake: take)?.updatedAt == TestData.now + 3600)
    }

    @Test func aQueueSavedBeforeTheTimestampStillOpens() throws {
        let old = Data(#"[{"takeID":"00000000-0000-0000-0000-000000000009","operationID":"00000000-0000-0000-0000-00000000000A","title":"A","items":[{"network":"tiktok","state":"pending"}]}]"#.utf8)
        let queues = try JSONDecoder().decode([ShareQueue].self, from: old)
        #expect(queues.first?.updatedAt == nil && queues.first?.current?.network == .tiktok)
    }

    @Test func aNewQueueForTheSameVideoReplacesTheOldOne() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        let take = UUID()
        service.begin(takeID: take, operationID: UUID(), title: "A", networks: [.tiktok])
        service.begin(takeID: take, operationID: UUID(), title: "A", networks: [.linkedin, .shorts])
        #expect(service.queues.count == 1 && service.queue(forTake: take)?.count == 2)
    }

    @Test func aQueueGoesWhenEveryNetworkIsPosted() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        let take = UUID()
        service.begin(takeID: take, operationID: UUID(), title: "A", networks: [.tiktok, .reels])
        service.markPosted(takeID: take, network: .tiktok)
        service.markPosted(takeID: take, network: .reels)
        #expect(service.queue(forTake: take) == nil && service.pending == nil)
    }

    @Test func aQueueWithNetworksLeftForLaterStaysButHasNothingPending() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        let take = UUID()
        service.begin(takeID: take, operationID: UUID(), title: "A", networks: [.tiktok, .linkedin])
        service.markPosted(takeID: take, network: .tiktok)
        service.moveRestToLater(takeID: take)
        #expect(service.pending == nil, "no card: nothing is waiting its turn")
        #expect(service.later(forTake: take).map(\.network) == [.linkedin], "but POST TO LINKEDIN LATER is there")
    }

    @Test func theCardTalksAboutTheOldestQueueWithATurn() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        let first = UUID()
        let second = UUID()
        service.begin(takeID: first, operationID: UUID(), title: "First", networks: [.tiktok])
        service.begin(takeID: second, operationID: UUID(), title: "Second", networks: [.reels])
        #expect(service.pending?.takeID == first)
        service.moveRestToLater(takeID: first)
        #expect(service.pending?.takeID == second)
    }
}
