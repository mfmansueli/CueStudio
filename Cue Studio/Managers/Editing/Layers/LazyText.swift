//
//  LazyText.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// A caption drawn when it shows rather than ahead: a video's captions (and, with word effects,
/// one drawing per word) would otherwise all sit in memory at the output's resolution.
nonisolated struct LazyText: Sendable {
    let text: TextOverlay
    let emphasis: WordEmphasis?
    let frameWidth: CGFloat
    let widthFraction: CGFloat
    var collection: CaptionSettings?
    var frameHeight: CGFloat = 0

    /// Names this drawing in the compositor's cache: the line, its word and size, and everything the
    /// drawing depends on, so a corrected word or a new style is drawn again when the compositor
    /// (and its cache) outlives the change, as in the preview.
    var key: String {
        var drawing = Hasher()
        drawing.combine(text)
        drawing.combine(emphasis)
        drawing.combine(collection)
        drawing.combine(widthFraction)
        drawing.combine(frameHeight)
        return "\(text.id.uuidString)-\(emphasis?.index ?? -1)-\(Int(frameWidth.rounded()))-\(drawing.finalize())"
    }
}
