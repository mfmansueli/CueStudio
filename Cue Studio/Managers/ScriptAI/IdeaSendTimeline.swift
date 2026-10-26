//
//  IdeaSendTimeline.swift
//  Cue Studio
//

import os

/// What an idea's send does on the main thread before its star moves, each step an interval (`studio.cue` / Send): Instruments and
/// `PerformanceDeviceUITests` read how long each took. The first send after a launch was where the app stood still (26/10/2026).
nonisolated enum IdeaSendTimeline {
    private static let signposter = OSSignposter(subsystem: "studio.cue", category: "Send")

    /// Runs `work` inside the interval `name`.
    static func measure<Result>(_ name: StaticString, _ work: () throws -> Result) rethrows -> Result {
        let interval = signposter.beginInterval(name, id: signposter.makeSignpostID())
        defer { signposter.endInterval(name, interval) }
        return try work()
    }
}
