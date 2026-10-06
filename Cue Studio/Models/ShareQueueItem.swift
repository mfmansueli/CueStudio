//
//  ShareQueueItem.swift
//  Cue Studio
//

import Foundation

/// One network of a "Share to universe" queue (8.1): where the video still has to be posted, was posted, or is left for later.
nonisolated struct ShareQueueItem: Codable, Hashable, Identifiable, Sendable {
    enum State: String, Codable, Sendable {
        /// Waiting its turn, or the one being posted now.
        case pending
        /// The creator said "Yes, it's live".
        case posted
        /// "Post later", or the queue was closed with this one left.
        case later
    }

    let network: ShareDestination
    var state: State

    var id: String { network.rawValue }
}
