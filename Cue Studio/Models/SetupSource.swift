//
//  SetupSource.swift
//  Cue Studio
//

import Foundation

/// Why a recording uses a value, so the creator always knows where it came from.
nonisolated enum SetupSource: Hashable, Sendable {
    /// Their Creator Setup ("This is what you usually use").
    case creatorSetup
    /// A platform recommendation they accepted for this content.
    case recommended(Platform)
    /// Changed for this take only.
    case thisTake

    /// "Your setup", "TikTok setup", "This take".
    var label: String {
        switch self {
        case .creatorSetup: String(localized: "Your setup")
        case .recommended(let platform): String(localized: "\(platform.label) setup")
        case .thisTake: String(localized: "This take")
        }
    }
}
