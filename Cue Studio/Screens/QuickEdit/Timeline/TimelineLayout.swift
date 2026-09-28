//
//  TimelineLayout.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where everything sits on the Quick edit timeline, in points. Pure, so the mapping between
/// touches and time is tested without a screen.
///
/// The Trim strip lays out what the handles can reach (`EditTimeline.reachable`, the same item the
/// preview plays): the sections in play order with a hairline between them, plus what the handles
/// trimmed off, dimmed, before the start handle and after the end handle. Removed sections leave no
/// gap. A trim only moves the handles; the scale changes when something is removed from inside.
/// Clean Up's strip (`showsTrimmedEnds: false`) shows the edited video alone.
///
/// Ready for zoom: `zoom` above 1 widens every second and `offset` scrolls.
nonisolated struct TimelineLayout {
    /// Room for a yellow handle on each side of the frames.
    static let handleWidth: CGFloat = 16
    /// Between two sections.
    static let joinWidth: CGFloat = 2
    /// How far past a handle's outer side a touch still catches it.
    static let handleOuterReach: CGFloat = 8
    /// How far into the kept frames a touch still catches a handle.
    static let handleReach: CGFloat = 14
    /// Touches this close to the playhead drag it from where it is instead of jumping.
    static let playheadReach: CGFloat = 16
    /// Touches this close to an edge of the red range move that edge (a 32 pt target).
    static let removalEdgeReach: CGFloat = 16

    /// A stretch of the strip.
    struct Region: Hashable {
        let index: Int
        let minX: CGFloat
        let maxX: CGFloat
        /// The part of the recording drawn there.
        let source: TimeSpan

        var width: CGFloat { max(0, maxX - minX) }
    }

    /// The edit.
    let timeline: EditTimeline
    let width: CGFloat
    /// Space left and right of the frames (the handles' room).
    let inset: CGFloat
    /// Points per second, the same all along the strip.
    let pointsPerSecond: CGFloat
    /// What the strip draws, one per section in play order (with the trimmed ends when they show).
    let regions: [Region]
    /// The timeline drawn: the edit, or the edit with its ends grown to the whole recording.
    private let strip: EditTimeline
    /// Seconds of the strip before the edit starts (what the start handle trimmed, when it shows).
    private let lead: TimeInterval

    init(
        timeline: EditTimeline, width: CGFloat, inset: CGFloat = TimelineLayout.handleWidth,
        showsTrimmedEnds: Bool = true, zoom: CGFloat = 1, offset: CGFloat = 0
    ) {
        self.timeline = timeline
        self.width = width
        self.inset = inset
        let strip = showsTrimmedEnds ? timeline.reachable : timeline
        self.strip = strip
        lead = showsTrimmedEnds ? timeline.trimStart : 0
        let joins = CGFloat(strip.segments.count - 1) * Self.joinWidth
        let seconds = strip.editedDuration
        let room = max(0, width - 2 * inset - joins)
        let scale = seconds > 0 ? room / CGFloat(seconds) * max(1, zoom) : 0
        pointsPerSecond = scale

        var regions: [Region] = []
        var x = inset - offset
        for (index, segment) in strip.segments.enumerated() {
            if index > 0 { x += Self.joinWidth }
            let end = x + CGFloat(segment.duration) * scale
            regions.append(Region(index: index, minX: x, maxX: end, source: segment.span))
            x = end
        }
        self.regions = regions
    }

    // MARK: - The edit on the strip

    /// The start handle's inner edge, where the edit begins.
    var startHandleX: CGFloat { x(forStrip: lead) }

    /// The end handle's inner edge, where the edit ends.
    var endHandleX: CGFloat { x(forStrip: lead + timeline.editedDuration) }

    /// The section of the edit at `index`, between the handles.
    func piece(_ index: Int) -> Region {
        let region = regions[index]
        let last = timeline.segments.count - 1
        return Region(
            index: index,
            minX: index == 0 ? max(region.minX, startHandleX) : region.minX,
            maxX: index == last ? min(region.maxX, endHandleX) : region.maxX,
            source: timeline.segments[index].span
        )
    }

    /// Where `time` (edited seconds) is drawn; held between the handles.
    func x(forEdited time: TimeInterval) -> CGFloat {
        x(forStrip: lead + min(max(0, time), timeline.editedDuration))
    }

    /// The edited moment at `x`: held between the handles, and at the start of the next section on
    /// the hairline between two.
    func editedTime(atX x: CGFloat) -> TimeInterval {
        min(max(0, stripTime(atX: x) - lead), timeline.editedDuration)
    }

    /// The moment of the recording drawn at `x` (in the trimmed ends too): where a handle goes
    /// when the finger is there.
    func sourceTime(atX x: CGFloat) -> TimeInterval {
        strip.sourceTime(forEdited: stripTime(atX: x))
    }

    /// The section of the edit drawn at `x`, or nil outside the handles.
    func segmentIndex(atX x: CGFloat) -> Int? {
        timeline.segments.indices.first { piece($0).minX <= x && x <= piece($0).maxX + Self.joinWidth }
    }

    // MARK: - Touch

    /// What a touch at `x` grabs. Above the frames (`aboveFrames`, the playhead's knob row) the
    /// playhead comes first, so it can always be caught, even sitting on a handle. On the frames the
    /// handles come first (each reaches 38 pt, however thin it looks), so the playhead never keeps
    /// a handle from moving; then the playhead's line, else the timeline. With the red range
    /// showing, its edges come first and nothing trims.
    func target(
        atX x: CGFloat, playheadX: CGFloat, aboveFrames: Bool = false, removal: ClosedRange<TimeInterval>? = nil
    ) -> TimelineTouchTarget {
        let nearPlayhead = abs(x - playheadX) <= Self.playheadReach
        if aboveFrames { return nearPlayhead ? .playhead : .timeline }
        if let removal {
            let startX = self.x(forEdited: removal.lowerBound)
            let endX = self.x(forEdited: removal.upperBound)
            let toStart = abs(x - startX)
            let toEnd = abs(x - endX)
            if min(toStart, toEnd) <= Self.removalEdgeReach {
                return .removalEdge(toStart < toEnd ? .start : .end)
            }
        } else if let handle = handle(atX: x) {
            return .handle(handle)
        }
        return nearPlayhead ? .playhead : .timeline
    }

    /// The handle a touch at `x` catches: the same reach on both, mirrored, and the nearer one
    /// when they are close together.
    func handle(atX x: CGFloat) -> TrimHandle? {
        let outer = Self.handleWidth + Self.handleOuterReach
        let nearStart = x >= startHandleX - outer && x <= startHandleX + Self.handleReach
        let nearEnd = x >= endHandleX - Self.handleReach && x <= endHandleX + outer
        switch (nearStart, nearEnd) {
        case (true, true):
            let toStart = abs(x - (startHandleX - Self.handleWidth / 2))
            let toEnd = abs(x - (endHandleX + Self.handleWidth / 2))
            return toStart <= toEnd ? .start : .end
        case (true, false): return .start
        case (false, true): return .end
        case (false, false): return nil
        }
    }

    /// How many frames to read for a strip this wide: two per tile, so sections cut anywhere still
    /// find a frame close to their own time. Never more than 60, whatever the take's length.
    static func frameCount(width: CGFloat, tileWidth: CGFloat) -> Int {
        guard tileWidth > 0 else { return 8 }
        return min(60, max(8, Int((width / tileWidth).rounded(.up)) * 2))
    }

    // MARK: - Strip time

    /// Where a moment of the strip (seconds from its start) is drawn.
    private func x(forStrip time: TimeInterval) -> CGFloat {
        guard !regions.isEmpty else { return inset }
        let index = strip.segmentIndex(atEdited: time)
        let offset = min(max(0, time - strip.editedStart(ofSegmentAt: index)), strip.segments[index].duration)
        return regions[index].minX + CGFloat(offset) * pointsPerSecond
    }

    /// The moment of the strip at `x`, on the hairline the start of the next section.
    private func stripTime(atX x: CGFloat) -> TimeInterval {
        guard pointsPerSecond > 0 else { return lead }
        for index in strip.segments.indices {
            let region = regions[index]
            let start = strip.editedStart(ofSegmentAt: index)
            if x < region.minX { return start }
            if x <= region.maxX {
                let offset = min(Double((x - region.minX) / pointsPerSecond), strip.segments[index].duration)
                return min(start + offset, strip.editedDuration)
            }
        }
        return strip.editedDuration
    }
}
