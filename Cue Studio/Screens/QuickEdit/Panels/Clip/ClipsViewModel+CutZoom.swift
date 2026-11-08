//
//  ClipsViewModel+CutZoom.swift
//  Cue Studio
//

import Foundation

/// Zoom › Punch in on cuts (`CutZoom`, plan §11; R1.3/R2.1: it took 9–10 taps, clip by clip): one switch puts every other clip a
/// little closer, at Subtle, Medium or Strong, as one undo step said in a toast with Undo. Only when the creator turns it on (F16);
/// a clip zoomed or cropped by hand keeps what they did, and the timeline's badges show where each punch-in lands.
extension ClipsViewModel {
    var punchesInOnCuts: Bool { edit.cutZoom != nil }

    /// The clips Punch in on cuts puts closer now, or would with the switch on.
    var punchedClipCount: Int {
        (edit.cutZoom ?? CutZoom()).punchedClips(of: edit.timeline).filter { $0 }.count
    }

    /// Whether there is a cut to punch in on.
    var canPunchInOnCuts: Bool { edit.timeline.segments.count > 1 }

    /// The switch, at the strength the kit marked (`TakeEdit.phraseZoomStrength`) or Medium: one undo step, said with Undo, and
    /// the first punch-in shown.
    func setPunchesInOnCuts(_ on: Bool) {
        guard isReady, on != punchesInOnCuts, !on || canPunchInOnCuts else { return }
        let strength = edit.phraseZoomStrength ?? .medium
        changeEdit { $0.cutZoom = on ? CutZoom(strength: strength) : nil }
        guard on else {
            sayUndoable(String(localized: "Punch in on cuts off"))
            return
        }
        let count = punchedClipCount
        sayUndoable(count == 0
            ? String(localized: "No clip is long enough to punch in yet", comment: "Toast: Punch in on cuts is on, but every clip is too short")
            : String(localized: "Punch in on \(count) clips", comment: "Toast: Punch in on cuts put this many clips closer"))
        previewFirstPunchIn()
    }

    func setCutZoomStrength(_ strength: PhraseZoom.Strength) {
        guard isReady, let zoom = edit.cutZoom, zoom.strength != strength else { return }
        changeEdit { $0.cutZoom?.strength = strength }
        previewFirstPunchIn()
    }

    /// The line under the switch about the picked clip: it keeps its own zoom, or it is too short to change at its cut.
    var cutZoomClipNote: String? {
        guard punchesInOnCuts, let clip = targetClip, let index = edit.timeline.index(ofSegment: clip.id) else { return nil }
        if clip.zoom != nil || clip.crop != nil { return String(localized: "This clip keeps the zoom and crop you gave it") }
        if index > 0, !edit.timeline.continuesFromPrevious(index), clip.duration < CutZoom.minimumClip {
            return String(localized: "Clips under \(DurationText.tenths(CutZoom.minimumClip)) keep the zoom of the clip before them")
        }
        return nil
    }

    /// From a moment before the first clip it puts closer, so Play shows the punch-in.
    private func previewFirstPunchIn() {
        guard let zoom = edit.cutZoom, let index = zoom.punchedClips(of: edit.timeline).firstIndex(of: true) else { return }
        let cut = edit.timeline.editedStart(ofSegmentAt: index)
        let start = max(0, cut - Self.transitionLeadIn)
        previewPart(start...min(edit.timeline.editedDuration, cut + Self.transitionLeadIn), back: start)
    }
}
