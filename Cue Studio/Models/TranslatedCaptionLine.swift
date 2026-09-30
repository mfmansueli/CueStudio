//
//  TranslatedCaptionLine.swift
//  Cue Studio
//

import Foundation

/// A caption line in another language. It covers one or more original lines (a sentence is
/// translated whole, for context, then broken into lines that read comfortably), shows over their
/// time shared by length (the words of a translation don't line up with the voice, so nothing is
/// lit word by word), and remembers what the original said when it was translated: when that
/// changes, the line says it's outdated rather than being replaced.
nonisolated struct TranslatedCaptionLine: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    /// The original lines it translates.
    var cueIDs: [UUID]
    /// What they said when this was translated.
    var sourceText: String
    var text: String
    /// Seconds of the recording.
    var start: TimeInterval
    var end: TimeInterval
    /// The recording the original lines were heard in (nil: the take itself).
    var sourceID: UUID?
    /// Written or corrected by the creator: translating again keeps it unless asked.
    var isRevised = false

    /// The line as a caption to draw (no word times: it shows whole).
    var cue: CaptionCue {
        var cue = CaptionCue(id: id, text: text, start: start, end: end, origin: isRevised ? .manual : .speech)
        cue.sourceID = sourceID
        return cue
    }
}
