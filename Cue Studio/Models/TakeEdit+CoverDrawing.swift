//
//  TakeEdit+CoverDrawing.swift
//  Cue Studio
//

import Foundation

extension TakeEdit {
    /// Everything the drawn cover depends on: the cover, the format and crop it's cut to, and the looks and backgrounds of the
    /// clips its frame can come from. The timeline's cover block is drawn again when this changes, so it never shows an old
    /// format or look.
    var coverDrawingKey: Int {
        var hasher = Hasher()
        hasher.combine(cover)
        hasher.combine(aspect)
        hasher.combine(cropOffset)
        hasher.combine(cropFit)
        hasher.combine(LookSettings(self))
        hasher.combine(backgrounds)
        // Which clips play and their looks: a frame whose clip went falls back to its recording's look.
        hasher.combine(timeline.segments)
        return hasher.finalize()
    }
}
