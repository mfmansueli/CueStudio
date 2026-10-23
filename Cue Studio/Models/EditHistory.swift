//
//  EditHistory.swift
//  Cue Studio
//

import Foundation

/// Undo and redo as a list of real states (not of gestures): undoing hands back the state before
/// the last change, redoing the one that was undone. Changes with the same key less than
/// `coalescingInterval` apart (a slider, a drag, typing) are one step.
nonisolated struct EditHistory<State: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    /// Steps kept; the oldest go first.
    static var limit: Int { 60 }
    /// Changes of one kind closer than this join the step before.
    static var coalescingInterval: TimeInterval { 0.9 }

    private(set) var past: [State] = []
    private(set) var future: [State] = []
    /// The kind of the last change and when it was made, to join the next one to it.
    private var lastKey: String?
    private var lastDate: Date?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case past, future
    }

    /// Remembers the state before a change, unless it continues the last one (same `key`, within
    /// `coalescingInterval`): then the step that change made already goes back far enough.
    mutating func record(_ previous: State, key: String?, at date: Date) {
        defer {
            lastKey = key
            lastDate = date
        }
        if let key, key == lastKey, let lastDate, date.timeIntervalSince(lastDate) < Self.coalescingInterval, !past.isEmpty {
            future.removeAll()
            return
        }
        record(previous)
    }

    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    /// Remembers the state before a change. A new change forgets what was undone.
    mutating func record(_ previous: State) {
        lastKey = nil
        past.append(previous)
        if past.count > Self.limit { past.removeFirst(past.count - Self.limit) }
        future.removeAll()
    }

    /// The state to go back to, or nil when there is none.
    mutating func undo(from current: State) -> State? {
        lastKey = nil
        guard let previous = past.popLast() else { return nil }
        future.append(current)
        return previous
    }

    /// The state that was undone last, or nil when there is none.
    mutating func redo(from current: State) -> State? {
        lastKey = nil
        guard let next = future.popLast() else { return nil }
        past.append(current)
        return next
    }

    /// The same steps, each written relative to the state it is applied on (`thin(step, newer)`; the newest undo and redo
    /// steps are applied on `current`), so a saved history doesn't hold the same big part once per step.
    func thinned(current: State, _ thin: (_ step: State, _ newer: State) -> State) -> EditHistory {
        var copy = self
        copy.past = Self.thinned(past, current: current, thin)
        copy.future = Self.thinned(future, current: current, thin)
        return copy
    }

    /// The last step is applied on `current`, each one before it on the step after it.
    private static func thinned(_ steps: [State], current: State, _ thin: (State, State) -> State) -> [State] {
        var newer = current
        var thinned = steps
        for index in steps.indices.reversed() {
            thinned[index] = thin(steps[index], newer)
            newer = steps[index]
        }
        return thinned
    }
}
