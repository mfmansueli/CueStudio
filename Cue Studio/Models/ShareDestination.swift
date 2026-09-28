//
//  ShareDestination.swift
//  Cue Studio
//

import Foundation

/// Where "Share to" sends a take. Cue has no platform SDKs: the video is saved to Photos and the
/// app is opened, ready to pick it; without the app, the system share sheet takes over.
nonisolated enum ShareDestination: String, CaseIterable, Identifiable, Sendable {
    case tiktok, reels, shorts, youtube, linkedin, stories

    var id: String { rawValue }

    init(_ platform: Platform) {
        switch platform {
        case .tiktok: self = .tiktok
        case .reels: self = .reels
        case .shorts: self = .shorts
        case .youtube: self = .youtube
        case .linkedin: self = .linkedin
        case .stories: self = .stories
        }
    }

    var platform: Platform {
        switch self {
        case .tiktok: .tiktok
        case .reels: .reels
        case .shorts: .shorts
        case .youtube: .youtube
        case .linkedin: .linkedin
        case .stories: .stories
        }
    }

    /// Letters on the tile, as in the design.
    var glyph: String {
        switch self {
        case .tiktok: "T"
        case .reels: "R"
        case .shorts: "S"
        case .youtube: "Y"
        case .linkedin: "in"
        case .stories: "St"
        }
    }

    /// The app's own URL scheme; it opens where the creator picks the video.
    var appURL: URL? {
        switch self {
        case .tiktok: URL(string: "tiktok://")
        case .reels, .stories: URL(string: "instagram://")
        case .shorts, .youtube: URL(string: "youtube://")
        case .linkedin: URL(string: "linkedin://")
        }
    }
}
