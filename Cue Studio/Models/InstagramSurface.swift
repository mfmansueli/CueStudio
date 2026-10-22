//
//  InstagramSurface.swift
//  Cue Studio
//

import Foundation

/// The two places in Instagram that take a video from another app, each with its own URL scheme and limits (Meta's
/// "Sharing to Reels" and "Sharing to Stories" docs for iOS).
nonisolated enum InstagramSurface: Equatable, Sendable {
    case reels, stories

    /// Reels: 3 to 60 s. Stories: up to 20 s (Meta's asset tables). A video outside these is not sent this way.
    func accepts(duration: TimeInterval) -> Bool {
        switch self {
        case .reels: (3...60).contains(duration)
        case .stories: duration > 0 && duration <= 20
        }
    }
}
