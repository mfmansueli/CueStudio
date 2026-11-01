//
//  TakeEdit+CaptionsHeard.swift
//  Cue Studio
//

import Foundation

/// A draft left open while the take was exported with captions: the export listened to the take and kept what it heard on the take's own
/// edit (`TakeLibraryService.cacheCaptions`), so the draft, finished later, mustn't save over them.
nonisolated extension TakeEdit {
    /// This edit with the captions `finished` (the take's edit) was given meanwhile, only when this one never had captions of its own: no
    /// lines and nothing heard, so lines the creator removed stay removed and lines they corrected stay theirs.
    func withCaptionsHeardMeanwhile(from finished: TakeEdit) -> TakeEdit {
        guard captions.isEmpty, captionTranscript == nil, !finished.captions.isEmpty, let heard = finished.captionTranscript else { return self }
        var caught = self
        caught.captions = finished.captions.map(CaptionRevision.withoutContinuation)
        caught.captionTranscript = heard
        return caught
    }
}
