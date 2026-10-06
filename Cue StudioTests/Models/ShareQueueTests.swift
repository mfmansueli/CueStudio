//
//  ShareQueueTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The order of a "Share to universe" queue (8.1): whose turn it is, what was posted, what waits for later.
@Suite("ShareQueue")
struct ShareQueueTests {
    private func queue(_ networks: [ShareDestination] = [.tiktok, .reels, .linkedin]) -> ShareQueue {
        ShareQueue(takeID: UUID(), operationID: UUID(), title: "3 habits", networks: networks)
    }

    @Test func theFirstNetworkIsCurrentAndTheNextIsAfterIt() {
        let queue = queue()
        #expect(queue.current?.network == .tiktok && queue.next?.network == .reels)
        #expect(queue.count == 3 && queue.hasPending)
        #expect(queue.position(of: queue.items[1]) == 2)
    }

    @Test func aPostedNetworkMovesTheTurnOn() {
        var queue = queue()
        queue.markPosted(.tiktok)
        #expect(queue.current?.network == .reels && queue.posted == [.tiktok])
        queue.markPosted(.reels)
        queue.markPosted(.linkedin)
        #expect(queue.current == nil && queue.isDone)
    }

    @Test func postLaterMovesOnWithoutPostingAndTheQueueIsNotDone() {
        var queue = queue()
        queue.postLater(.tiktok)
        #expect(queue.current?.network == .reels)
        #expect(queue.later.map(\.network) == [.tiktok])
        queue.markPosted(.reels)
        queue.markPosted(.linkedin)
        #expect(!queue.isDone, "TikTok is still waiting for later")
        #expect(!queue.hasPending)
    }

    @Test func theLastNetworkHasNoNext() {
        var queue = queue([.tiktok, .reels])
        queue.markPosted(.tiktok)
        #expect(queue.current?.network == .reels && queue.next == nil)
    }

    @Test func closingLeavesEverythingPendingForLater() {
        var queue = queue()
        queue.markPosted(.tiktok)
        queue.moveRestToLater()
        #expect(queue.later.map(\.network) == [.reels, .linkedin])
        #expect(queue.posted == [.tiktok] && !queue.hasPending)
    }

    @Test func aNetworkLeftForLaterCanBeResumed() {
        var queue = queue([.tiktok, .linkedin])
        queue.markPosted(.tiktok)
        queue.postLater(.linkedin)
        queue.resume(.linkedin)
        #expect(queue.current?.network == .linkedin && queue.later.isEmpty)
    }

    @Test func theQueueRoundTripsThroughJSON() throws {
        var original = queue()
        original.markPosted(.tiktok)
        original.postLater(.reels)
        let decoded = try JSONDecoder().decode(ShareQueue.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}
