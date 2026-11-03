//
//  ScriptTypingTimeline.swift
//  Cue Studio
//

import os
import QuartzCore

/// What each letter typed in a script's words costs the main thread, step by step (`studio.cue` / Typing): the change asked, the edit
/// reported, the caret, the page's update of the editor, its measure and its layout. `PerformanceDeviceUITests` reads how long each took;
/// typing must feel as fluid as Notes, whatever the script's length (the owner, 03/11/2026).
nonisolated enum ScriptTypingTimeline {
    private static let signposter = OSSignposter(subsystem: "studio.cue", category: "Typing")

    /// Runs `work` inside the interval `name`.
    static func measure<Result>(_ name: StaticString, _ work: () throws -> Result) rethrows -> Result {
        let interval = signposter.beginInterval(name, id: signposter.makeSignpostID())
        #if DEBUG
        let start = probes ? CACurrentMediaTime() : 0
        defer {
            if probes {
                let seconds = CACurrentMediaTime() - start
                MainActor.assumeIsolated { ScriptTypingProbe.note("\(name)", seconds: seconds) }
            }
        }
        #endif
        defer { signposter.endInterval(name, interval) }
        return try work()
    }

    #if DEBUG
    /// `-uiTestTypingProbe`: each step also goes to the probe (always on the main thread, where the editor and the page run).
    private static let probes = ProcessInfo.processInfo.arguments.contains("-uiTestTypingProbe")
    #endif
}
