//
//  TimelineLayout.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where everything sits on the Quick edit timeline, in points. The strip is the edited video:
/// its sections in play order, a hairline between them, nothing of what was trimmed or removed.
/// Pure, so the mapping between touches and time is tested without a screen.
///
/// A trim rescales the strip once the handle is let go; while it's dragged, the strip keeps the
/// layout it had when the drag started. Ready for zoom: `zoom` above 1 widens every second and
/// `offset` scrolls.
nonisolated struct TimelineLayout {
    /// Room for a yellow handle on each side of the frames.
    static let handleWidth: CGFloat = 16
    /// Between two sections.
    static let joinWidth: CGFloat = 2
    /// How far into the frames a touch still catches a handle, on top of the handle itself.
    static let handleReach: CGFloat = 14
    /// Touches this close to the playhead drag it from where it is instead of jumping.
    static let playheadReach: CGFloat = 16
    /// Touches this close to an edge of the red range move that edge (a 32 pt target).
    static let removalEdgeReach: CGFloat = 16

    /// A section of the edit on the strip.
    struct Region: Hashable {
        let index: Int
        let minX: CGFloat
        let maxX: CGFloat
        /// The part of the recording drawn there.
        let source: TimeSpan

        var width: CGFloat { max(0, maxX - minX) }
    }

    let timeline: EditTimeline
    let width: CGFloat
    /// Space left and right of the frames (the handles' room).
    let inset: CGFloat
    /// Points per second of the edit, the same all along the strip.
    let pointsPerSecond: CGFloat
    /// One per section, in play order.
    let regions: [Region]

    init(timeline: EditTimeline, width: CGFloat, inset: CGFloat = TimelineLayout.handleWidth, zoom: CGFloat = 1, offset: CGFloat = 0) {
        self.timeline = timeline
        self.width = width
        self.inset = inset
        let joins = CGFloat(timeline.segments.count - 1) * Self.joinWidth
        let seconds = timeline.editedDuration
        let room = max(0, width - 2 * inset - joins)
        let scale = seconds > 0 ? room / CGFloat(seconds) * max(1, zoom) : 0
        pointsPerSecond = scale

        var regions: [Region] = []
        var x = inset - offset
        for (index, segment) in timeline.segments.enumerated() {
            if index > 0 { x += Self.joinWidth }
            let end = x + CGFloat(segment.duration) * scale
            regions.append(Region(index: index, minX: x, maxX: end, source: segment.span))
            x = end
        }
        self.regions = regions
    }

    /// The region of the section at `index`.
    func piece(_ index: Int) -> Region {
        regions[index]
    }

    /// The start handle's inner edge, where the edit begins.
    var startHandleX: CGFloat { piece(0).minX }

    /// The end handle's inner edge, where the edit ends.
    var endHandleX: CGFloat { piece(timeline.segments.count - 1).maxX }

    /// Where `time` (edited seconds) is drawn.
    func x(forEdited time: TimeInterval) -> CGFloat {
        let index = timeline.segmentIndex(atEdited: time)
        let offset = min(max(0, time - timeline.editedStart(ofSegmentAt: index)), timeline.segments[index].duration)
        return piece(index).minX + CGFloat(offset) * pointsPerSecond
    }

    /// The edited moment at `x`: held to the sections, and at the start of the next section on
    /// the hairline between two.
    func editedTime(atX x: CGFloat) -> TimeInterval {
        guard pointsPerSecond > 0 else { return 0 }
        for index in timeline.segments.indices {
            let region = piece(index)
            let start = timeline.editedStart(ofSegmentAt: index)
            if x < region.minX { return start }
            if x <= region.maxX {
                let offset = min(Double((x - region.minX) / pointsPerSecond), timeline.segments[index].duration)
                return min(start + offset, timeline.editedDuration)
            }
        }
        return timeline.editedDuration
    }

    /// The moment of the recording drawn at `x`.
    func sourceTime(atX x: CGFloat) -> TimeInterval {
        guard pointsPerSecond > 0, let first = regions.first else { return 0 }
        if x <= first.minX { return first.source.start }
        for region in regions where x <= region.maxX {
            let offset = Double(max(0, x - region.minX) / pointsPerSecond)
            return min(region.source.start + offset, region.source.end)
        }
        return regions.last?.source.end ?? 0
    }

    /// The section drawn at `x`, or nil beside the sections (on the handles).
    func segmentIndex(atX x: CGFloat) -> Int? {
        timeline.segments.indices.first { piece($0).minX <= x && x <= piece($0).maxX + Self.joinWidth }
    }

    /// What a touch at `x` grabs. With the red range showing, its edges first and no trim;
    /// otherwise a handle first (its reach extends into the frames, so a thin handle is still easy
    /// to catch), then the playhead, else the timeline.
    func target(atX x: CGFloat, playheadX: CGFloat, removal: ClosedRange<TimeInterval>? = nil) -> TimelineTouchTarget {
        if let removal {
            let startX = self.x(forEdited: removal.lowerBound)
            let endX = self.x(forEdited: removal.upperBound)
            let toStart = abs(x - startX)
            let toEnd = abs(x - endX)
            if min(toStart, toEnd) <= Self.removalEdgeReach {
                return .removalEdge(toStart < toEnd ? .start : .end)
            }
        } else {
            let nearStart = x >= startHandleX - Self.handleWidth - 8 && x <= startHandleX + Self.handleReach
            let nearEnd = x >= endHandleX - Self.handleReach && x <= endHandleX + Self.handleWidth + 8
            if nearStart, nearEnd {
                // Handles close together: the nearer one.
                let toStart = abs(x - (startHandleX - Self.handleWidth / 2))
                let toEnd = abs(x - (endHandleX + Self.handleWidth / 2))
                return .handle(toStart <= toEnd ? .start : .end)
            }
            if nearStart { return .handle(.start) }
            if nearEnd { return .handle(.end) }
        }
        if abs(x - playheadX) <= Self.playheadReach { return .playhead }
        return .timeline
    }

    /// How many frames to read for a strip this wide: two per tile, so sections cut anywhere still
    /// find a frame close to their own time. Never more than 60, whatever the take's length.
    static func frameCount(width: CGFloat, tileWidth: CGFloat) -> Int {
        guard tileWidth > 0 else { return 8 }
        return min(60, max(8, Int((width / tileWidth).rounded(.up)) * 2))
    }
}
