//
//  WatchCommand.swift
//  Cue Studio
//

import Foundation

/// One request from the watch, with an id so its answer is told apart from an older one.
nonisolated struct WatchCommand: Codable, Hashable, Sendable, Identifiable {
    var id = UUID()
    var action: WatchAction
}
