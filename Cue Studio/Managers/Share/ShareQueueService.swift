//
//  ShareQueueService.swift
//  Cue Studio
//

import Foundation

/// The "Share to universe" queues that are not finished (8.1, 6.3), kept on this iPhone so that "Continue posting" is still there after the creator
/// leaves for a network's app, closes Cue or goes to another screen. A queue goes once every network is posted.
@MainActor
@Observable
final class ShareQueueService {
    private(set) var queues: [ShareQueue]

    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.defaults = defaults
        self.now = now
        queues = defaults.data(forKey: DefaultsKey.shareQueues).flatMap { try? JSONDecoder().decode([ShareQueue].self, from: $0) } ?? []
    }

    // MARK: - Reading

    func queue(forTake takeID: UUID) -> ShareQueue? { queues.first { $0.takeID == takeID } }

    /// The queue the "Continue posting" card talks about: the oldest one that still has a network to post.
    var pending: ShareQueue? { queues.first(where: \.hasPending) }

    /// The networks of this take left for later ("POST TO LINKEDIN LATER").
    func later(forTake takeID: UUID) -> [ShareQueueItem] { queue(forTake: takeID)?.later ?? [] }

    // MARK: - Changing

    /// A new queue for a video (it replaces one that was left for it before).
    @discardableResult
    func begin(takeID: UUID, operationID: UUID, title: String, networks: [ShareDestination]) -> ShareQueue {
        let queue = ShareQueue(takeID: takeID, operationID: operationID, title: title, networks: networks, updatedAt: now())
        queues.removeAll { $0.takeID == takeID }
        queues.append(queue)
        save()
        return queue
    }

    func markPosted(takeID: UUID, network: ShareDestination) { change(takeID) { $0.markPosted(network) } }

    func postLater(takeID: UUID, network: ShareDestination) { change(takeID) { $0.postLater(network) } }

    func moveRestToLater(takeID: UUID) { change(takeID) { $0.moveRestToLater() } }

    func resume(takeID: UUID, network: ShareDestination) { change(takeID) { $0.resume(network) } }

    func discard(takeID: UUID) {
        queues.removeAll { $0.takeID == takeID }
        save()
    }

    private func change(_ takeID: UUID, _ change: (inout ShareQueue) -> Void) {
        guard let index = queues.firstIndex(where: { $0.takeID == takeID }) else { return }
        change(&queues[index])
        queues[index].updatedAt = now()
        if queues[index].isDone { queues.remove(at: index) }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(queues), forKey: DefaultsKey.shareQueues)
    }
}
