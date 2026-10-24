//
//  SplitRatio.swift
//  Cue Studio
//

import Foundation

/// How a split screen shares the frame: evenly, or 60/40 with the larger share to one content (`SplitLayout.larger`).
nonisolated enum SplitRatio: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = SplitRatio.even

    case even
    case sixtyForty

    var id: String { rawValue }

    var label: String {
        switch self {
        case .even: "50/50"
        case .sixtyForty: "60/40"
        }
    }

    /// The larger area's share of the frame.
    var largerShare: Double {
        switch self {
        case .even: 0.5
        case .sixtyForty: 0.6
        }
    }
}
