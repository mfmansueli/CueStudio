//
//  TakeEdit+Zoom.swift
//  Cue Studio
//

import Foundation

nonisolated extension TakeEdit {
    /// The timeline as it is drawn: with Punch in on cuts written on its clips (`CutZoom.punched`), else as it is. What draws or
    /// places something on the picture reads this (the composition, the handles over the preview, the timeline's badges);
    /// what edits the clips reads `timeline`.
    var punchedTimeline: EditTimeline {
        cutZoom.map { $0.punched(timeline) } ?? timeline
    }
}
