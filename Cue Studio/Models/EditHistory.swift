//
//  EditHistory.swift
//  Cue Studio
//

import Foundation

/// Undo and redo as a list of real states (not of gestures): undoing hands back the state before
/// the last change, redoing the one that was undone.
nonisolated struct EditHistory<State: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    /// Steps kept; the oldest go first.
    static var limit: Int { 100 }

    private(set) var past: [State] = []
    private(set) var future: [State] = []

    init() {}

    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    /// Remembers the state before a change. A new change forgets what was undone.
    mutating func record(_ previous: State) {
        past.append(previous)
        if past.count > Self.limit { past.removeFirst(past.count - Self.limit) }
        future.removeAll()
    }

    /// The state to go back to, or nil when there is none.
    mutating func undo(from current: State) -> State? {
        guard let previous = past.popLast() else { return nil }
        future.append(current)
        return previous
    }

    /// The state that was undone last, or nil when there is none.
    mutating func redo(from current: State) -> State? {
        guard let next = future.popLast() else { return nil }
        past.append(current)
        return next
    }
}
