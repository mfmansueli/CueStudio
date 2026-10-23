//
//  LoadingProgress.swift
//  Cue Studio
//

import Foundation
import os

/// The `Progress` of a library item being loaded (`EditMediaImporter`): reports how far it is on the main actor and stops it
/// when the import is cancelled, even if that happens before the loading has started. Its state is only touched behind the
/// lock, hence `@unchecked`.
nonisolated final class LoadingProgress: @unchecked Sendable {
    private struct State {
        var progress: Progress?
        var observation: NSKeyValueObservation?
        var isCancelled = false
    }

    private let state = OSAllocatedUnfairLock(uncheckedState: State())

    func watch(_ progress: Progress, report: @escaping @MainActor (Double) -> Void) {
        let observation = progress.observe(\.fractionCompleted, options: [.new]) { progress, _ in
            let fraction = progress.fractionCompleted
            Task { @MainActor in report(fraction) }
        }
        let cancelled = state.withLockUnchecked { state in
            state.progress = progress
            state.observation = observation
            return state.isCancelled
        }
        if cancelled { progress.cancel() }
    }

    func cancel() {
        let progress = state.withLockUnchecked { state in
            state.isCancelled = true
            return state.progress
        }
        progress?.cancel()
    }
}
