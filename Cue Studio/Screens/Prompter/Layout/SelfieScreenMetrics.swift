//
//  SelfieScreenMetrics.swift
//  Cue Studio
//

import CoreGraphics

/// What the Selfie screen measured on this device, in points from the screen's top-left corner.
/// Until the first measurement it holds the design screen (iPhone 17, 402 × 874).
nonisolated struct SelfieScreenMetrics: Equatable, Sendable {
    var screen = CGSize(width: 402, height: 874)
    /// Top safe-area inset: status bar, Dynamic Island or notch.
    var topInset: CGFloat = 62
    /// Bottom of the top bar (close, Selfie | Studio, platform chip).
    var topBarBottom: CGFloat = 106
    /// Top of the toolbar at the bottom.
    var toolbarTop: CGFloat = 628
    /// Where the preview layer draws the camera image, once the camera runs.
    var videoRect: CGRect?

    /// Where the front camera sits. It's in the Dynamic Island or the notch, centered in the status
    /// bar area on every iPhone that has one; there is no API for the lens position, so this is the
    /// estimate the reading line is measured from.
    var lensY: CGFloat { topInset / 2 }
}
