//
//  FullScreenMorph.swift
//  Cue Studio
//

import CoreGraphics

/// The video growing out of its card in the editor into full screen, as a function of how far along it is: where the picture
/// is and how big, how round its corners are, how much of the editor the dark around it covers, and where the arrow rides (from
/// the card's foot to over the full screen hint). `shown` is 0 at the card and 1 in full screen, and goes a little past either
/// end while the spring settles. With Reduce Motion nothing moves: full screen fades in over the editor. Pure, so the geometry
/// is tested without a screen.
nonisolated struct FullScreenMorph: Equatable, Sendable {
    /// The video's card in the editor, and the video in full screen, in the screen's points.
    let card: CGRect
    let full: CGRect
    let screen: CGSize
    /// The card's corner radius.
    let cardRadius: CGFloat
    let moves: Bool
    var shown: CGFloat

    /// The arrow's height under the card's foot and over the hint (`PreviewFullScreenArrow`, its hit target).
    static let arrowHeight: CGFloat = 44
    /// The hint's top over the screen's foot ("Tap video to play · tap outside to exit": 30 pt tall, 40 pt up).
    static let hintTop: CGFloat = 70

    /// `shown` within 0…1, for what doesn't overshoot.
    var cover: CGFloat { min(max(shown, 0), 1) }

    /// Measured: the card and the full screen picture are known.
    private var isMeasured: Bool { moves && card.width > 0 && full.width > 0 }

    /// The full screen picture's size, as a part of it.
    var scale: CGFloat {
        guard isMeasured else { return 1 }
        let start = card.width / full.width
        return start + (1 - start) * shown
    }

    /// The full screen picture's way from its place to the card's.
    var offset: CGSize {
        guard isMeasured else { return .zero }
        return CGSize(width: (card.midX - full.midX) * (1 - shown), height: (card.midY - full.midY) * (1 - shown))
    }

    /// The corners in the picture's own (unscaled) points: the card's at the start, square in full screen.
    var cornerRadius: CGFloat {
        guard isMeasured else { return 0 }
        return cardRadius * (1 - cover) / max(scale, 0.01)
    }

    /// The picture: whole from the start while it moves (it comes in exactly over the card, which stays under it), fading in
    /// place with Reduce Motion.
    var pictureOpacity: CGFloat { isMeasured ? 1 : cover }

    /// The hint comes in at the end.
    var hintOpacity: CGFloat { min(max((cover - 0.7) / 0.3, 0), 1) }

    /// The arrow's middle: at the card's foot, then over the hint.
    var arrowCenter: CGPoint {
        let resting = CGPoint(x: screen.width / 2, y: screen.height - Self.hintTop - 4 - Self.arrowHeight / 2)
        guard isMeasured else { return resting }
        let start = CGPoint(x: card.midX, y: card.maxY - Self.arrowHeight / 2)
        return CGPoint(x: start.x + (resting.x - start.x) * cover, y: start.y + (resting.y - start.y) * cover)
    }
}
