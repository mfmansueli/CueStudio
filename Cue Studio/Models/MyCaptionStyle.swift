//
//  MyCaptionStyle.swift
//  Cue Studio
//

import Foundation

/// A caption combination the creator saved (`SavedStyle`, Caption style › Styles › Mine): the look (the style, what was
/// changed over it, how it moves) and the layout (size, place, width, alignment, format), used again on the next videos (new
/// captions start in the default one). Never the words, the timing or the safe margins of the platform a video is for.
nonisolated struct MyCaptionStyle: Codable, Hashable, Sendable {
    var settings: CaptionSettings
    var animation: CaptionAnimation

    init(settings: CaptionSettings, animation: CaptionAnimation) {
        self.settings = settings
        self.animation = animation
    }

    /// The style of `edit`'s captions now; nil while they have no collection (an edit from before presets).
    init?(of edit: TakeEdit) {
        guard let settings = edit.captionCollection else { return nil }
        self.settings = settings
        animation = edit.captionAnimation
    }
}
