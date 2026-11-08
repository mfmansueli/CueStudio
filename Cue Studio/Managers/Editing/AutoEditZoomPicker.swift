//
//  AutoEditZoomPicker.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// Auto edit's zoom step: the lines worth a phrase zoom are the ones Suggest emphasis would single a word out in (a clear number,
/// value or name, `CaptionEmphasisSuggester`), never two zooms closer than `spacing`, never on a line already zoomed. Pure.
nonisolated enum AutoEditZoomPicker {
    /// Seconds of the recording between the starts of two zooms: closer, it would read as frantic (plan §11).
    static let spacing: TimeInterval = 6

    /// Zooms for `lines` (in play order; only lines that play), at `strength`.
    static func zooms(for lines: [CaptionCue], existing: [PhraseZoom], strength: PhraseZoom.Strength, language: NLLanguage?) -> [PhraseZoom] {
        var picked: [PhraseZoom] = []
        var lastStart: [UUID?: TimeInterval] = [:]
        for line in lines where CaptionEmphasisSuggester.suggestion(in: line.text, language: language) != nil {
            let taken = (existing + picked).contains { $0.sourceID == line.sourceID && $0.span.overlaps(line.span) }
            guard !taken else { continue }
            if let last = lastStart[line.sourceID], abs(line.start - last) < spacing { continue }
            picked.append(PhraseZoom(span: line.span, sourceID: line.sourceID, strength: strength))
            lastStart[line.sourceID] = line.start
        }
        return picked
    }
}
