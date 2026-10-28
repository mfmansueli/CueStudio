//
//  TimelineChange.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// What changed between two drawings of the timeline that is worth a short motion (each 0.3 s or less): an item that came in
/// grows from its start and its strip flashes in its colour, what went away shrinks out and what was after it closes the space,
/// what was just picked springs in with its handles, and a track brought under the video rises into place. Only a creator's own
/// step moves: a whole new set (captions made, an undo of many) is drawn in place. Pure, so what moves is tested without a screen.
nonisolated struct TimelineChange: Equatable, Sendable {
    static let none = TimelineChange()
    /// The most items or clips that come or go at once with motion.
    static let motionLimit = 3

    /// Items that came in (an add, a split, an undo bringing one back).
    var added: Set<UUID> = []
    /// The tracks they came in on.
    var addedLanes: Set<TimelineLane> = []
    /// Items and clips that went away.
    var removed: Set<UUID> = []
    /// Clips and items that moved across because something before them went away, by how far they were (old x − new x).
    var shifts: [UUID: CGFloat] = [:]
    /// Something was just picked.
    var picked = false
    /// The track that took the place under the video, collapsed.
    var arrivedLane: TimelineLane?

    init() {}

    init(from old: TimelineGeometry?, to new: TimelineGeometry) {
        guard let old else { return }
        picked = new.input.selection != nil && new.input.selection != old.input.selection
        if let was = old.chooser, let now = new.chooser, !was.isExpanded, !now.isExpanded, was.lane != now.lane {
            arrivedLane = now.lane
        }
        let oldItems = Self.items(of: old.input)
        let newItems = Self.items(of: new.input)
        let came = newItems.filter { oldItems[$0.key] == nil }
        if (1...Self.motionLimit).contains(came.count) {
            added = Set(came.keys)
            addedLanes = Set(came.values)
        }
        let newClips = Set(new.input.clips.map(\.id))
        let oldClips = Set(old.input.clips.map(\.id))
        let went = Set(oldItems.keys.filter { newItems[$0] == nil }).union(oldClips.subtracting(newClips))
        // A whole set replaced (captions made again) is drawn in place, what it replaced too.
        guard came.count <= Self.motionLimit, (1...Self.motionLimit).contains(went.count) else { return }
        removed = went
        // Only a removal moves what was after it (a trim or a zoom moves things too, and those follow the finger).
        guard came.isEmpty, newClips.isSubset(of: oldClips), new.pointsPerSecond == old.pointsPerSecond else { return }
        let oldX = Self.starts(of: old)
        for (id, x) in Self.starts(of: new) {
            guard let was = oldX[id], abs(was - x) > 0.5 else { continue }
            shifts[id] = was - x
        }
    }

    /// Every item of the edit and its track, shown or not (a track that isn't out still has its items).
    private static func items(of input: TimelineGeometry.Input) -> [UUID: TimelineLane] {
        var items: [UUID: TimelineLane] = [:]
        let tracks: [([TimelineGeometry.ItemInput], TimelineLane)] = [
            (input.texts, .text), (input.media, .media), (input.blurs, .blur),
            (input.showsCaptions ? input.captions : [], .captions), (input.music, .music), (input.voiceOvers, .voiceOver),
        ]
        for (inputs, lane) in tracks {
            for item in inputs { items[item.id] = lane }
        }
        return items
    }

    /// Where each clip and each drawn item starts.
    private static func starts(of geometry: TimelineGeometry) -> [UUID: CGFloat] {
        var starts: [UUID: CGFloat] = [:]
        for clip in geometry.clips { starts[clip.id] = clip.frame.minX }
        for item in geometry.items { starts[item.id] = item.frame.minX }
        return starts
    }
}
