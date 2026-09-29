//
//  LayerLanes.swift
//  Cue Studio
//

import Foundation

/// Stacks bars that overlap in time into lanes, so two texts on screen at once are both
/// reachable. Pure, so it's tested without a screen.
enum LayerLanes {
    /// Most lanes a track shows; more overlapping bars share the last one.
    static let maximum = 3

    /// The lane of each bar, by id: the first one free when it starts, in start order.
    static func lanes(for bars: [LayerBar]) -> [UUID: Int] {
        var ends: [TimeInterval] = []
        var result: [UUID: Int] = [:]
        for bar in bars.sorted(by: { $0.span.start < $1.span.start }) {
            if let free = ends.firstIndex(where: { $0 <= bar.span.start + 0.001 }) {
                ends[free] = bar.span.end
                result[bar.id] = free
            } else if ends.count < maximum {
                ends.append(bar.span.end)
                result[bar.id] = ends.count - 1
            } else {
                let last = maximum - 1
                ends[last] = max(ends[last], bar.span.end)
                result[bar.id] = last
            }
        }
        return result
    }

    /// How many lanes `lanes` uses (at least one).
    static func count(_ lanes: [UUID: Int]) -> Int {
        (lanes.values.max() ?? 0) + 1
    }
}
