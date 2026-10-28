//
//  TimelineTrackChoice.swift
//  Cue Studio
//

import Foundation

/// The track the timeline shows under the video, and whether every track is out to choose another: collapsed, the timeline is
/// the video track and the current track alone, and the preview gets the room; ▾ beside the current track's icon brings the
/// others out in place, a tap on one makes it current and puts the rest away, ▴ puts them away as they were. Picking an item
/// on the preview, or opening a track's tools, brings that track. Pure, so the rules are tested without a screen.
nonisolated struct TimelineTrackChoice: Equatable, Sendable {
    /// The track chosen last (kept for each video). When it isn't on the timeline any more (its last item went), Texts shows,
    /// which always is; an Undo that brings the item back brings the track back with it.
    var current: TimelineLane = .text
    /// Every track is out to choose from.
    var isExpanded = false

    /// The track shown under the video among `lanes` (the timeline's full list, `TimelineGeometry.lanes`).
    func shown(in lanes: [TimelineLane]) -> TimelineLane? {
        if lanes.contains(current) { return current }
        // The shortcut to add music or a voice-over gave way to what was added.
        if current == .audio, let added = lanes.first(where: { $0 == .music || $0 == .voiceOver }) { return added }
        if lanes.contains(.text) { return .text }
        return lanes.first { $0 != .main }
    }

    /// The tracks the timeline shows: every one while they're out, else the video track and the current one.
    func lanes(from all: [TimelineLane]) -> [TimelineLane] {
        guard !isExpanded, let shown = shown(in: all) else { return all }
        return all.filter { $0 == .main || $0 == shown }
    }

    /// `lane` becomes the current track and the others go away; the video track is never chosen.
    mutating func choose(_ lane: TimelineLane) {
        isExpanded = false
        guard lane != .main else { return }
        current = lane
    }

    /// The first of `lanes` that `all` has becomes current (an item picked, a track's tools opened), else the first of them: a
    /// track whose first item is on its way (Blur area opened to add one) shows once the item is there. The current track stays
    /// when it is one of them (Audio's tools opened from the voice-over's track keep the voice-over).
    mutating func bring(anyOf lanes: [TimelineLane], in all: [TimelineLane]) {
        let candidates = lanes.filter { $0 != .main }
        if candidates.contains(current), all.contains(current) {
            isExpanded = false
            return
        }
        guard let lane = candidates.first(where: all.contains) ?? candidates.first else { return }
        choose(lane)
    }
}
