//
//  FakeFaceFinderHook.swift
//  Cue StudioTests
//

import Foundation

/// What runs the first time `FakeFaceFinder` is asked, while the call is suspended: what the creator does meanwhile (another
/// tap included, awaited to its end).
nonisolated final class FakeFaceFinderHook: @unchecked Sendable {
    var whileFinding: (@MainActor @Sendable () async -> Void)?

    /// The action, handed out once.
    func take() -> (@MainActor @Sendable () async -> Void)? {
        defer { whileFinding = nil }
        return whileFinding
    }
}
