//
//  SectionZoom.swift
//  Cue Studio
//

import Foundation

/// A slow zoom on a section, without keyframes: the common way to keep a talking head alive or to
/// soften a jump cut. It is part of the section, so it moves, copies and splits with it.
nonisolated enum SectionZoom: String, Codable, CaseIterable, Identifiable, Sendable {
    /// From the frame as filmed, slowly closer.
    case pushIn
    /// From closer, slowly back to the frame as filmed.
    case pullOut
    /// Closer the whole section (a punch-in after a cut).
    case punchIn

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pushIn: String(localized: "Push in")
        case .pullOut: String(localized: "Pull out")
        case .punchIn: String(localized: "Punch in")
        }
    }

    /// How much closer, at most.
    static let depth: Double = 0.12

    /// Times the frame's size, `progress` (0 to 1) through the section.
    func scale(at progress: Double) -> Double {
        let eased = KeyframeEasing.smooth.apply(progress)
        switch self {
        case .pushIn: return 1 + Self.depth * eased
        case .pullOut: return 1 + Self.depth * (1 - eased)
        case .punchIn: return 1 + Self.depth * 1.25
        }
    }
}
