//
//  LayerLanes.swift
//  Cue Studio
//

import Foundation

/// How many bars overlap in time, so a track never holds more photos or videos on screen at once
/// than it can show. Pure, so it's tested without a screen.
enum LayerLanes {
    /// The most of `spans` that play at the same moment anywhere inside `within`.
    static func peak(of spans: [TimeSpan], within: TimeSpan) -> Int {
        let inside = spans.filter { $0.overlaps(within) }
        let moments = inside.map { max($0.start, within.start) } + [within.start]
        return moments.map { moment in inside.filter { $0.start <= moment + 0.000_1 && moment < $0.end - 0.000_1 }.count }.max() ?? 0
    }
}
