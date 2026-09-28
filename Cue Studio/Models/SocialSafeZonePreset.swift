//
//  SocialSafeZonePreset.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where a platform's own interface (buttons, caption, header, reply bar) covers the video, as
/// margins in pixels of the exported frame (VideoSpace). A visual guide based on each app's current
/// layout, not a guarantee: platforms change their UI, so the numbers ship in
/// `PlatformRules.json` and can be updated without a new build.
nonisolated struct SocialSafeZonePreset: Codable, Hashable, Sendable {
    /// The frame the margins were measured on.
    var aspect: AspectRatio
    /// Pixel size of that frame (1080 × 1920 for 9:16, 1080 × 1350 for 4:5).
    var videoWidth: Double
    var videoHeight: Double
    var top: Double
    var bottom: Double
    var left: Double
    var right: Double

    var videoSize: CGSize { CGSize(width: videoWidth, height: videoHeight) }

    /// The part of the frame the platform leaves clear, in VideoSpace.
    var recommendedContentRect: CGRect {
        CGRect(x: left, y: top, width: videoWidth - left - right, height: videoHeight - top - bottom)
    }

    /// Margins that fit inside their frame and leave some of it clear. (Not through the rect:
    /// `CGRect` reports a negative size as positive.)
    var isValid: Bool {
        min(top, bottom, left, right) >= 0 && videoWidth - left - right > 0 && videoHeight - top - bottom > 0
    }
}
