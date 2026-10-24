//
//  PresetCardMotion.swift
//  Cue Studio
//

import UIKit

/// A style card's sample that plays (`PanelPresetCard`): the renderer's drawings of the sample line over a loop, the first
/// coming in the style's way (fade, pop, rise), as the video plays them.
struct PresetCardMotion: Equatable {
    struct Frame: Equatable {
        let start: TimeInterval
        let image: UIImage
    }

    let frames: [Frame]
    let loop: TimeInterval
    var fadeIn: TimeInterval = 0
    var popScale = 1.0
    var popDuration: TimeInterval = 0
    /// Points the sample rises from, on the card.
    var rise: CGFloat = 0
    var riseDuration: TimeInterval = 0
}
