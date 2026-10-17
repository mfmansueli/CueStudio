//
//  BackgroundExportRunning.swift
//  Cue Studio
//

import Foundation

@MainActor
protocol BackgroundExportRunning: AnyObject {
    /// Runs an export from the file to where it goes, so it can go on when the creator leaves Cue: `started` hears how it
    /// runs before the work begins, and `work` reports its progress (0 to 1). Throws `BackgroundExportError.stoppedBySystem`
    /// when iOS ends it early.
    func run<Value: Sendable>(
        title: String,
        subtitle: String,
        started: @MainActor (BackgroundExportMode) -> Void,
        work: @escaping @MainActor (_ progress: @escaping @MainActor (Double) -> Void) async throws -> Value
    ) async throws -> Value
}
