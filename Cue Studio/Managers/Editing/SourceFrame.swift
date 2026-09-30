//
//  SourceFrame.swift
//  Cue Studio
//

import CoreGraphics

/// How a recording's frames become the edit's frame: its track's transform (portrait recordings
/// upright), the part of the upright frame to keep, and the scale that brings it to the take's
/// frame size (1 for the take itself; another take or video of a montage is scaled to match), and
/// its background effect.
nonisolated struct SourceFrame: Sendable {
    let transform: CGAffineTransform
    /// Core Image coordinates.
    let crop: CGRect
    let scale: CGFloat
    var background: BackgroundRender? = nil
}
