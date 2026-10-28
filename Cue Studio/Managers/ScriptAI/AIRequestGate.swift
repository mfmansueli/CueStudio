//
//  AIRequestGate.swift
//  Cue Studio
//

import Synchronization

/// Mutex-protected one-shot continuation; completion may arrive before installation or cancellation.
nonisolated final class AIRequestGate<Value: Sendable>: Sendable {
    private struct State {
        var continuation: CheckedContinuation<Value?, Never>?
        var finished = false
        var value: Value?
    }

    private let state = Mutex(State())

    func install(_ continuation: CheckedContinuation<Value?, Never>) {
        let result = state.withLock { state -> (Bool, Value?) in
            if state.finished { return (true, state.value) }
            state.continuation = continuation
            return (false, nil)
        }
        if result.0 { continuation.resume(returning: result.1) }
    }

    func finish(_ value: Value?) {
        let continuation = state.withLock { state -> CheckedContinuation<Value?, Never>? in
            guard !state.finished else { return nil }
            state.finished = true
            state.value = value
            defer { state.continuation = nil }
            return state.continuation
        }
        continuation?.resume(returning: value)
    }
}
