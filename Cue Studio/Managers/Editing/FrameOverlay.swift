//
//  FrameOverlay.swift
//  Cue Studio
//

import CoreGraphics
import CoreImage

/// An image laid over the video for part of it: a caption while its words are said, or the
/// "Made with Cue" badge for the whole take. Rendered once, then composited on each frame.
nonisolated struct FrameOverlay: @unchecked Sendable {
    let image: CIImage
    /// Where it goes, in the output frame (Core Image coordinates: origin at the bottom left).
    let origin: CGPoint
    /// Seconds in the edited video; nil for always.
    let span: TimeSpan?

    func isVisible(at time: TimeInterval) -> Bool {
        span?.contains(time) ?? true
    }
}
