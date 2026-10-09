//
//  ShareQueue.swift
//  Cue Studio
//

import Foundation

/// The networks one video goes to, one after the other (8.1 "Share to universe"): Cue opens the share sheet for each, the creator posts there and
/// comes back, and Cue asks "Posted on {network}?". Only a yes makes a network **posted**. Pure value logic; `ShareQueueService` keeps it.
nonisolated struct ShareQueue: Codable, Hashable, Identifiable, Sendable {
    let takeID: UUID
    /// The exported file all the networks share: one export, one count.
    var operationID: UUID
    /// The script's title, for "Next: TikTok · 3 habits that fixed my mornings".
    let title: String
    var items: [ShareQueueItem]
    /// When the creator last moved it (began it, posted, left a network for later). Nil in queues saved before notifications: they count
    /// from when the notifications started (`NotificationState.startedAt`).
    var updatedAt: Date?

    var id: UUID { takeID }

    init(takeID: UUID, operationID: UUID, title: String, networks: [ShareDestination], updatedAt: Date? = nil) {
        self.takeID = takeID
        self.operationID = operationID
        self.title = title
        items = networks.map { ShareQueueItem(network: $0, state: .pending) }
        self.updatedAt = updatedAt
    }

    // MARK: - Reading

    /// The network being posted now: the first one still pending.
    var current: ShareQueueItem? { items.first { $0.state == .pending } }

    /// The one after it, for "We'll open Reels next."
    var next: ShareQueueItem? { items.filter { $0.state == .pending }.dropFirst().first }

    var hasPending: Bool { current != nil }

    var count: Int { items.count }

    /// "1 OF 3": the position of `item` in the queue, from 1.
    func position(of item: ShareQueueItem) -> Int { (items.firstIndex { $0.network == item.network } ?? 0) + 1 }

    var posted: [ShareDestination] { items.filter { $0.state == .posted }.map(\.network) }

    var later: [ShareQueueItem] { items.filter { $0.state == .later } }

    /// Nothing is waiting any more, and nothing is left for later: the queue can go.
    var isDone: Bool { items.allSatisfy { $0.state == .posted } }

    // MARK: - Changing

    mutating func markPosted(_ network: ShareDestination) { set(network, to: .posted) }

    mutating func postLater(_ network: ShareDestination) { set(network, to: .later) }

    /// ✕ on the card or on the step: everything still pending is left for later.
    mutating func moveRestToLater() {
        for index in items.indices where items[index].state == .pending { items[index].state = .later }
    }

    /// "POST TO LINKEDIN LATER": a network left for later is the one being posted now.
    mutating func resume(_ network: ShareDestination) { set(network, to: .pending) }

    private mutating func set(_ network: ShareDestination, to state: ShareQueueItem.State) {
        guard let index = items.firstIndex(where: { $0.network == network }) else { return }
        items[index].state = state
    }
}
