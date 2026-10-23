//
//  MyCaptionStyle.swift
//  Cue Studio
//

import Foundation

/// Captions' "My style": the preset, the copied text look, size, highlight color, where the lines sit and how they come and go,
/// saved once and used again on the next videos (new captions start in it). Never the words, the timing or the safe margins
/// of the platform a video is for.
nonisolated struct MyCaptionStyle: Codable, Hashable, Sendable {
    var settings: CaptionSettings
    var animation: CaptionAnimation

    /// The style of `edit`'s captions now; nil while they have no collection (an edit from before presets).
    init?(of edit: TakeEdit) {
        guard let settings = edit.captionCollection else { return nil }
        self.settings = settings
        animation = edit.captionAnimation
    }

    /// `snapshot`'s captions in this style, keeping their own safe margins.
    func apply(to snapshot: inout EditSnapshot) {
        var mine = settings
        if let margins = snapshot.captionCollection?.safeMargins { mine.safeMargins = margins }
        snapshot.captionCollection = mine
        snapshot.captionAnimation = animation
    }

    /// Whether `edit`'s captions look like this now.
    func isWorn(by edit: TakeEdit) -> Bool {
        guard var current = edit.captionCollection else { return false }
        current.safeMargins = settings.safeMargins
        return current == settings && edit.captionAnimation == animation
    }
}
