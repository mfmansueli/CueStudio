//
//  Platform.swift
//  Cue Studio
//

import Foundation

/// Where a script will be posted ("Create for"). Drives the capture preset, the prompter position,
/// the safe zones and the length goals. Raw values are the keys of `PlatformRules.json`.
nonisolated enum Platform: String, Codable, CaseIterable, Identifiable, Sendable {
    case tiktok, reels, shorts, youtube, linkedin, stories

    var id: String { rawValue }

    /// Platforms offered as library and takes filters and when generating: Stories are too short
    /// to plan a script around, so they only show up once a script uses them.
    static let primary: [Platform] = [.tiktok, .reels, .shorts, .youtube, .linkedin]

    /// What the AI reads (English, whatever the interface language is).
    var promptName: String {
        switch self {
        case .tiktok: "TikTok"
        case .reels: "Instagram Reels"
        case .shorts: "YouTube Shorts"
        case .youtube: "YouTube (long-form)"
        case .linkedin: "LinkedIn"
        case .stories: "Instagram Stories"
        }
    }

    var label: String {
        switch self {
        case .tiktok: String(localized: "TikTok")
        case .reels: String(localized: "Reels")
        case .shorts: String(localized: "Shorts")
        case .youtube: String(localized: "YouTube")
        case .linkedin: String(localized: "LinkedIn")
        case .stories: String(localized: "Stories")
        }
    }

    /// Longer name used by "Create for" and its confirmation.
    var destinationName: String {
        switch self {
        case .tiktok: String(localized: "TikTok")
        case .reels: String(localized: "Instagram Reels")
        case .shorts: String(localized: "YouTube Shorts")
        case .youtube: String(localized: "YouTube · long-form")
        case .linkedin: String(localized: "LinkedIn")
        case .stories: String(localized: "Instagram Stories")
        }
    }
}
