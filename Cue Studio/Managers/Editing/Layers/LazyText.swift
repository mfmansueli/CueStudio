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

    /// Names this drawing in the compositor's cache.
    var key: String {
        "\(text.id.uuidString)-\(emphasis?.index ?? -1)-\(Int(frameWidth.rounded()))"
    }
}
