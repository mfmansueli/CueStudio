//
//  CoverCropGuide.swift
//  Cue Studio
//

import Foundation

/// A dashed frame on Cover Studio's canvas showing roughly what a profile grid shows of the cover. Approximations: each app
/// crops its own way and changes it, and Cue doesn't set the cover in any app, so the label says "approx.".
enum CoverCropGuide: String, CaseIterable, Identifiable {
    case none
    /// TikTok's and Instagram's grids show about a 3:4 middle.
    case portrait
    /// Older grids and some shelves show a square.
    case square

    var id: String { rawValue }

    /// Width over height of the part shown; nil for none.
    var aspect: Double? {
        switch self {
        case .none: nil
        case .portrait: 3.0 / 4.0
        case .square: 1
        }
    }

    var label: String {
        switch self {
        case .none: String(localized: "No crop guide")
        case .portrait: String(localized: "Profile grid 3:4 · approx.")
        case .square: String(localized: "Square 1:1 · approx.")
        }
    }
}
