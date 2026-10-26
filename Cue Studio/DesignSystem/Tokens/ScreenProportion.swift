//
//  ScreenProportion.swift
//  Cue Studio
//

import UIKit

/// How the interface's type follows the iPhone's width: the boards are drawn 390–402 pt wide, and there it is drawn at their sizes; a
/// little smaller on the narrowest iPhones (SE, mini, 375 pt) and a little bigger on the widest (Air, Pro Max, 420–440 pt), so a screen
/// keeps the proportions of its board instead of looking small on a big screen and cramped on a small one (the owner's call, 26/10/2026).
/// Dynamic Type scales on top of it (`InterfaceType`).
nonisolated enum ScreenProportion {
    /// The narrowest and widest widths the boards' sizes are kept for.
    static let boardWidths: ClosedRange<CGFloat> = 390...402
    /// The factor at 375 pt and at 440 pt; in between it follows the width, beyond them it stops.
    static let smallest: CGFloat = 0.96
    static let largest: CGFloat = 1.08

    /// The factor for a screen `width` points wide.
    static func factor(forWidth width: CGFloat) -> CGFloat {
        if width < boardWidths.lowerBound {
            let narrowing = (boardWidths.lowerBound - width) / (boardWidths.lowerBound - 375)
            return max(smallest, 1 - narrowing * (1 - smallest))
        }
        if width > boardWidths.upperBound {
            let widening = (width - boardWidths.upperBound) / (440 - boardWidths.upperBound)
            return min(largest, 1 + widening * (largest - 1))
        }
        return 1
    }

    /// The factor for this iPhone (portrait only, so its width never changes); 1 until a window exists.
    @MainActor static var current: CGFloat {
        if let cached { return cached }
        let screens = UIApplication.shared.connectedScenes.lazy.compactMap { ($0 as? UIWindowScene)?.screen.bounds }
        guard let bounds = screens.first else { return 1 }
        let factor = factor(forWidth: min(bounds.width, bounds.height))
        cached = factor
        return factor
    }

    @MainActor private static var cached: CGFloat?
}
