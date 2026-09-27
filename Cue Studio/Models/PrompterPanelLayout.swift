//
//  PrompterPanelLayout.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where the Selfie script panel sits for a platform: close to the lens and clear of the platform's
/// own UI. `top` and `height` are points on the reference screen; `width` is a fraction of the
/// screen width.
nonisolated struct PrompterPanelLayout: Codable, Hashable, Sendable {
    /// Reading width the creator can pick in Display settings.
    static let widthRange: ClosedRange<Double> = 0.5...0.75

    var top: Double
    var height: Double
    var width: Double

    /// Top and height on a screen `screenHeight` tall.
    func verticalExtent(screenHeight: CGFloat, referenceHeight: CGFloat) -> (top: CGFloat, height: CGFloat) {
        guard referenceHeight > 0 else { return (top, height) }
        let scale = screenHeight / referenceHeight
        return (top * scale, height * scale)
    }
}
