//
//  CaptionMap.swift
//  Cue Studio
//

import Foundation

/// The captions timed to the edit (`TakeEdit.editedCaptionInstances`), worked out once per change of the lines or the cuts
/// and looked up by line or by moment, so a take of an hour with hundreds of lines stays quick: the list, the timeline's
/// bars, the line under the playhead (every frame) and a dragged line (every move) read it instead of mapping every line
/// again.
nonisolated struct CaptionMap {
    /// Each line where it plays, in order, with the line it comes from (a copied section shows a line again under another
    /// identity).
    let instances: [(line: CaptionCue, cueID: UUID)]
    private let indexByLine: [UUID: Int]
    /// Where each instance starts, in order: a moment is found by halving.
    private let starts: [TimeInterval]

    init(_ edit: TakeEdit) {
        instances = edit.editedCaptionInstances
        var index: [UUID: Int] = [:]
        for (position, instance) in instances.enumerated() where index[instance.line.id] == nil { index[instance.line.id] = position }
        indexByLine = index
        starts = instances.map(\.line.start)
    }

    var lines: [CaptionCue] { instances.map(\.line) }

    /// The line a line shown in the edit comes from (itself when it isn't a copy).
    func cueID(forLine id: UUID) -> UUID {
        indexByLine[id].map { instances[$0].cueID } ?? id
    }

    /// A line as it plays in the edit; nil when it was cut.
    func line(_ id: UUID) -> CaptionCue? {
        indexByLine[id].map { instances[$0].line }
    }

    /// The line playing at `time` (edited seconds): the last to start by then, while it lasts.
    func instance(at time: TimeInterval) -> (line: CaptionCue, cueID: UUID)? {
        var low = 0, high = starts.count
        while low < high {
            let middle = (low + high) / 2
            if starts[middle] <= time { low = middle + 1 } else { high = middle }
        }
        // Lines don't overlap; a short one inside a longer one (never made by Cue) is still found by looking back a little.
        var position = low - 1
        while position >= 0, low - position <= 4 {
            let line = instances[position].line
            if line.start <= time, time < line.end { return instances[position] }
            position -= 1
        }
        return nil
    }
}
