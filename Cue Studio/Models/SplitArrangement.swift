//
//  SplitArrangement.swift
//  Cue Studio
//

import Foundation

/// How a split screen divides the frame between its two areas.
nonisolated enum SplitArrangement: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = SplitArrangement.stacked

    /// One area over the other.
    case stacked
    /// One area beside the other.
    case sideBySide

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stacked: String(localized: "Top and bottom")
        case .sideBySide: String(localized: "Side by side")
        }
    }

    var systemImage: String {
        switch self {
        case .stacked: "rectangle.split.1x2"
        case .sideBySide: "rectangle.split.2x1"
        }
    }
}
