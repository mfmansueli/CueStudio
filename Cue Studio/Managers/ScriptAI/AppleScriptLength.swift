//
//  AppleScriptLength.swift
//  Cue Studio
//

import Foundation

/// Where Apple Intelligence aims on Auto inside the scripts' 1:15 to 2:30 (`ScriptRequestFactory.writingRange`, every network: the owner's
/// call, 04/11/2026). Ultra writes to the whole of it; Apple Intelligence to the part where it writes best (the owner:
/// "mede onde ele se sai melhor dentro desses limites de tempo das redes"), measured on iPhones with the Ultra study's blind judges
/// (`AppleStudyDeviceTests`, `tools/ultra/study/apple_run.py`). Until then it keeps 1:15 to 1:45, the range it was measured on before.
nonisolated enum AppleScriptLength {
    /// The window on Auto when the creator has no usual length of their own. Task-local, so a measurement tries another for its own writing
    /// only (`$window.withValue`).
    @TaskLocal static var window: ClosedRange<TimeInterval> = 75...105

    /// The most a creator's usual length takes Apple Intelligence on Auto: the window's top, never below the two minutes it had (the owner's
    /// call, 29/10/2026).
    static var ceiling: TimeInterval { max(window.upperBound, 120) }

    /// `window` inside `range` (`ScriptRequestFactory.writingRange`): never outside what a script is written to.
    static func window(within range: ClosedRange<TimeInterval>) -> ClosedRange<TimeInterval> {
        let low = min(max(window.lowerBound, range.lowerBound), range.upperBound)
        return low...max(low, min(window.upperBound, range.upperBound))
    }
}
