//
//  FullScreenSwipe.swift
//  Cue Studio
//

import CoreGraphics

/// The swipe on the preview that does what the player bar's full screen button does: down takes the video to full screen (it
/// grows over the editor), up brings it back (owner, 29/10/2026). Only a clearly vertical drag counts (sideways is someone
/// else's); halfway there, or thrown, it changes when the finger lets go. Pure, so the rule is tested without a screen.
nonisolated struct FullScreenSwipe: Equatable, Sendable {
    /// Points the finger travels for letting go to change the screen.
    static let distance: CGFloat = 45
    /// Where a throw would carry the finger for it to change the screen however short the drag.
    static let throwDistance: CGFloat = 200
    /// Points the finger travels for the video to grow all the way into full screen under it, or shrink back into its card.
    static let followDistance: CGFloat = 320

    /// In full screen, the way out is up; otherwise the way in is down.
    let isFullScreen: Bool

    /// Letting go after `translation`, headed for `predicted` (`DragGesture.Value.predictedEndTranslation`), changes the screen.
    func changes(_ translation: CGSize, predicted: CGSize) -> Bool {
        guard Self.isVertical(translation) else { return false }
        return toward(translation) >= Self.distance || toward(predicted) >= Self.throwDistance
    }

    /// How far the video has gone toward the other state under a drag of `translation`, following the finger: 0…1.
    func follow(_ translation: CGSize) -> CGFloat {
        guard Self.isVertical(translation) else { return 0 }
        return min(max(toward(translation) / Self.followDistance, 0), 1)
    }

    /// The finger's speed toward the other state at `velocity` (points per second), in `followDistance`s per second: what the
    /// spring that finishes the change starts with.
    func speed(_ velocity: CGSize) -> CGFloat {
        toward(velocity) / Self.followDistance
    }

    private func toward(_ translation: CGSize) -> CGFloat {
        isFullScreen ? -translation.height : translation.height
    }

    /// More than 1.2× as far up or down as sideways.
    private static func isVertical(_ translation: CGSize) -> Bool {
        abs(translation.height) > abs(translation.width) * 1.2
    }
}
