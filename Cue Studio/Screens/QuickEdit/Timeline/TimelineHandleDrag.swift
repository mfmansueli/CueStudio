//
//  TimelineHandleDrag.swift
//  Cue Studio
//

import Foundation

/// A handle held on the timeline: what it trims and where things were when the finger landed.
/// Every move starts again from here, so the whole drag is one undo step and dragging back
/// brings back what was trimmed.
struct TimelineHandleDrag: Equatable {
    let target: TimelineGeometry.HandleTarget
    /// The playhead when the drag began: it comes back there when the finger lifts.
    let playhead: TimeInterval
    /// Edited seconds of the held edge when the drag began.
    let edgeTime: TimeInterval
    /// A clip's stretch of its recording when the drag began (clips only).
    let clipSpan: TimeSpan?
    /// The clip's speed (clips only).
    let clipSpeed: Double
    /// The item's bar when the drag began (track items only).
    let bar: LayerBar?
    /// Edited seconds the edge sticks to (the item's own edges left out).
    let snapTimes: [TimeInterval]
}
