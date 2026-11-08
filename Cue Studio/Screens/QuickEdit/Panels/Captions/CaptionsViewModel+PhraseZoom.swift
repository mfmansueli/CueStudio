//
//  CaptionsViewModel+PhraseZoom.swift
//  Cue Studio
//

import Foundation

/// Zoom on a phrase from Captions › Select › Zoom (E4, owner 07/11/2026): the picked lines' seconds of the recording get a
/// zoom (`PhraseZoom`), lines said back to back as one, so it doesn't go out and in between them. From then on it is on its own:
/// a correction, a split or a deleted line leaves it as it is. No zoom takes away the zooms on the picked lines. One undo step.
extension CaptionsViewModel {
    /// Lines closer than this zoom as one phrase.
    static let phraseGap: TimeInterval = 0.35

    /// The zoom on the line `id` (any phrase zoom over its words), if it has one.
    func phraseZoom(onLine id: UUID) -> PhraseZoom? {
        guard let line = edit.captions.first(where: { $0.id == id }) else { return nil }
        return edit.phraseZooms.first { $0.sourceID == line.sourceID && $0.span.overlaps(line.span) }
    }

    /// The zoom the picked lines share: nil for none or when they differ.
    var pickedPhraseZoom: PhraseZoom.Strength? {
        phraseZoom(of: pickedCaptionLines)
    }

    /// The picked lines zoomed at `strength`, or not zoomed (nil).
    func setPickedCaptionsZoom(_ strength: PhraseZoom.Strength?) {
        setZoom(strength, onLines: pickedCaptionLines)
    }

    /// The zoom `lines` share: nil for none or when they differ.
    func phraseZoom(of lines: [CaptionCue]) -> PhraseZoom.Strength? {
        let strengths = Set(lines.map { phraseZoom(onLine: $0.id)?.strength })
        return strengths.count == 1 ? strengths.first ?? nil : nil
    }

    /// `lines` zoomed at `strength`, or not zoomed (nil), in one undo step.
    func setZoom(_ strength: PhraseZoom.Strength?, onLines lines: [CaptionCue]) {
        guard isReady, !lines.isEmpty else { return }
        var zooms = edit.phraseZooms.filter { zoom in
            !lines.contains { $0.sourceID == zoom.sourceID && $0.span.overlaps(zoom.span) }
        }
        if let strength {
            zooms += Self.phrases(of: lines).map { PhraseZoom(span: $0.span, sourceID: $0.sourceID, strength: strength) }
        }
        guard zooms != edit.phraseZooms else { return }
        changeEdit { $0.phraseZooms = zooms.sorted { $0.span.start < $1.span.start } }
        Haptics.selection()
        if let first = lines.first, let span = editedSpan(ofCaption: first.id) {
            player.pause()
            // From a little before, so the zoom is seen coming in.
            player.seek(to: max(0, span.start - 0.3))
        }
    }

    /// The lines' stretches of the recording, lines said back to back (in the same recording) as one.
    static func phrases(of lines: [CaptionCue]) -> [(span: TimeSpan, sourceID: UUID?)] {
        var phrases: [(span: TimeSpan, sourceID: UUID?)] = []
        for line in lines.sorted(by: { $0.start < $1.start }) {
            if let last = phrases.last, last.sourceID == line.sourceID, line.start - last.span.end < phraseGap, line.start >= last.span.start {
                phrases[phrases.count - 1].span = TimeSpan(start: last.span.start, end: max(last.span.end, line.end))
            } else {
                phrases.append((line.span, line.sourceID))
            }
        }
        return phrases
    }
}
