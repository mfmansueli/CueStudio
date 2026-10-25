//
//  MainSoundLevels.swift
//  Cue Studio
//

import Foundation

/// The main video's sound turned down (or off) while a support shows (`MediaOverlay.mainVolume`): the take track's levels
/// (`EditedComposition.levels`: each clip's volume, the dips at the cuts, the fades) times each window's factor, eased in
/// and out over a few hundredths of a second so it never clicks. Pure, so the export, the preview and the tests agree.
nonisolated enum MainSoundLevels {
    /// How long the sound takes to go down at a window's start and back up at its end.
    static let ramp: TimeInterval = 0.03

    /// A stretch of the edit (edited seconds) where the main video plays at `factor` of its level.
    struct Window: Hashable, Sendable {
        var span: TimeSpan
        var factor: Float
    }

    /// `levels` times `windows`. Without a window turning anything down, `levels` as they are.
    static func scaled(_ levels: [EditedComposition.Fade], by windows: [Window]) -> [EditedComposition.Fade] {
        let windows = windows.filter { $0.span.duration > 0 && abs($0.factor - 1) > 0.000_1 }
        guard !windows.isEmpty else { return levels }
        let fades = levels.sorted { $0.start < $1.start }
        var times = Set<TimeInterval>([0])
        for fade in fades {
            times.insert(fade.start)
            times.insert(fade.start + fade.duration)
        }
        for window in windows {
            let edge = min(ramp, window.span.duration / 2)
            times.formUnion([window.span.start, window.span.start + edge, window.span.end - edge, window.span.end])
        }
        let points = times.filter { $0 >= 0 }.sorted()
        var result: [EditedComposition.Fade] = []
        for (from, to) in zip(points, points.dropFirst()) where to - from > 0.000_01 {
            result.append(EditedComposition.Fade(
                start: from, duration: to - from,
                fromVolume: level(fades, at: from, before: false) * factor(windows, at: from, before: false),
                toVolume: level(fades, at: to, before: true) * factor(windows, at: to, before: true)
            ))
        }
        // After the last change, the level it ends on holds.
        if let last = points.last {
            let volume = level(fades, at: last, before: false) * factor(windows, at: last, before: false)
            result.append(EditedComposition.Fade(start: last, duration: 0, fromVolume: volume, toVolume: volume))
        }
        return result
    }

    /// The track's level at `time` as the mix plays `fades` (1 before the first): just before `time` (`before`), or from it.
    static func level(_ fades: [EditedComposition.Fade], at time: TimeInterval, before: Bool) -> Float {
        let started = fades.last { before ? $0.start < time - 0.000_001 : $0.start <= time + 0.000_001 }
        guard let fade = started else { return 1 }
        let end = fade.start + fade.duration
        guard fade.duration > 0, time < end - 0.000_001 else { return fade.toVolume }
        let progress = Float(max(0, time - fade.start) / fade.duration)
        return fade.fromVolume + (fade.toVolume - fade.fromVolume) * progress
    }

    /// The windows' factor at `time`: 1 outside them, eased at their edges.
    static func factor(_ windows: [Window], at time: TimeInterval, before: Bool) -> Float {
        var result: Float = 1
        for window in windows {
            let span = window.span
            let inside = before
                ? time > span.start + 0.000_001 && time <= span.end + 0.000_001
                : time >= span.start - 0.000_001 && time < span.end - 0.000_001
            guard inside else { continue }
            let edge = min(ramp, span.duration / 2)
            let fromStart = time - span.start
            let toEnd = span.end - time
            let ease = Float(min(1, max(0, min(fromStart, toEnd) / max(edge, 0.000_001))))
            result *= 1 + (window.factor - 1) * ease
        }
        return result
    }
}
