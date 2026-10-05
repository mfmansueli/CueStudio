//
//  DownloadCooldown.swift
//  Cue Studio
//

import Foundation

/// Remembers which speech models just failed to download, so starting again right away (the creator
/// opens another script, a recognizer restarts) doesn't ask the system for the same download over and
/// over while the iPhone is offline. A model is tried again after `duration`.
nonisolated struct DownloadCooldown: Sendable {
    /// How long a failed download isn't asked for again.
    static let duration: TimeInterval = 30

    private var failures: [String: TimeInterval] = [:]
    private let clock: @Sendable () -> TimeInterval

    init(clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.clock = clock
    }

    mutating func failed(_ locale: Locale) {
        failures[locale.identifier(.bcp47)] = clock()
    }

    func isCoolingDown(_ locale: Locale) -> Bool {
        guard let failedAt = failures[locale.identifier(.bcp47)] else { return false }
        return clock() - failedAt < Self.duration
    }
}
