//
//  TimelineLayout.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where everything sits on the Quick edit timeline, in points. Left to right: the part of the
/// recording before the start handle (dimmed, the handle can bring it back), the pieces in play
/// order with a hairline between them, and the part after the end handle. Removed pieces between
/// two others are not drawn: the active timeline is the edit. Pure, so the mapping between
/// touches and time is tested without a screen.
///
/// Every second of the recording is the same width, so trimming never rescales the strip under
/// the finger. Ready for zoom: `zoom` above 1 widens every second and `offset` scrolls.
nonisolated struct TimelineLayout {
    /// Room for a yellow handle on each side of the frames.
    static let handleWidth: CGFloat = 16
    /// Between two pieces.
    static let joinWidth: CGFloat = 2
    /// How far into the frames a touch still catches a handle, on top of the handle itself.
    static let handleReach: CGFloat = 14
    /// Touches this close to the playhead drag it from where it is instead of jumping.
    static let playheadReach: CGFloat = 16

    struct Region: Hashable {
        enum Kind: Hashable {
            case head
            case piece(Int)
            case tail
        }

        let kind: Kind
        let minX: CGFloat
        let maxX: CGFloat
        /// The part of the recording drawn there.
        let source: TimeSpan

        var width: CGFloat { max(0, maxX - minX) }
    }

    let timeline: EditTimeline
    let width: CGFloat
    /// Points per second of the recording, the same all along the strip.
    let pointsPerSecond: CGFloat
    /// Head, each piece, tail.
    let regions: [Region]

    init(timeline: EditTimeline, width: CGFloat, zoom: CGFloat = 1, offset: CGFloat = 0) {
        self.timeline = timeline
        self.width = width
        let joins = CGFloat(timeline.segments.count - 1) * Self.joinWidth
        let seconds = timeline.head.duration + timeline.editedDuration + timeline.tail.duration
        let room = max(0, width - 2 * Self.handleWidth - joins)
        let scale = seconds > 0 ? room / CGFloat(seconds) * max(1, zoom) : 0
        pointsPerSecond = scale

        var regions: [Region] = []
        var x = Self.handleWidth - offset
        func add(_ kind: Region.Kind, _ span: TimeSpan) {
            let end = x + CGFloat(span.duration) * scale
            regions.append(Region(kind: kind, minX: x, maxX: end, source: span))
            x = end
        }
        add(.head, timeline.head)
        for (index, segment) in timeline.segments.enumerated() {
            if index > 0 { x += Self.joinWidth }
            add(.piece(index), segment.span)
        }
        add(.tail, timeline.tail)
        self.regions = regions
    }

    /// The region of the piece at `index`.
    func piece(_ index: Int) -> Region {
        regions[index + 1]
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

    /// The edited moment at `x`: held to the pieces, and at the start of the next piece on the
    /// hairline between two.
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

    /// The moment of the recording drawn at `x`, under the dimmed ends too.
    func sourceTime(atX x: CGFloat) -> TimeInterval {
        guard pointsPerSecond > 0 else { return 0 }
        for region in regions where x <= region.maxX {
            let offset = Double(max(0, x - region.minX) / pointsPerSecond)
            return min(region.source.start + offset, region.source.end)
        }
        return timeline.sourceDuration
    }

    /// The piece drawn at `x`, or nil beside the pieces (dimmed ends, handles).
    func segmentIndex(atX x: CGFloat) -> Int? {
        timeline.segments.indices.first { piece($0).minX <= x && x <= piece($0).maxX + Self.joinWidth }
    }

    /// What a touch at `x` grabs: a handle first (its reach extends into the frames, so a thin
    /// handle is still easy to catch), then the playhead, else the timeline.
    func target(atX x: CGFloat, playheadX: CGFloat) -> TimelineTouchTarget {
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
        if abs(x - playheadX) <= Self.playheadReach { return .playhead }
        return .timeline
    }

    /// How many frames to read for a strip this wide: two per tile, so pieces cut anywhere still
    /// find a frame close to their own time. Never more than 60, whatever the take's length.
    static func frameCount(width: CGFloat, tileWidth: CGFloat) -> Int {
        guard tileWidth > 0 else { return 8 }
        return min(60, max(8, Int((width / tileWidth).rounded(.up)) * 2))
    }
}
