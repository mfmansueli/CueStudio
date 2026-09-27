//
//  Platform.swift
//  Cue Studio
//

import Foundation

/// Where a script will be posted. Drives the capture preset and the length goals.
nonisolated enum Platform: String, Codable, CaseIterable, Identifiable, Sendable {
    case tiktok, reels, shorts, youtube

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tiktok: String(localized: "TikTok")
        case .reels: String(localized: "Reels")
        case .shorts: String(localized: "Shorts")
        case .youtube: String(localized: "YouTube")
        }
    }

    /// Longer name used by the destination picker.
    var destinationName: String {
        switch self {
        case .tiktok: String(localized: "TikTok")
        case .reels: String(localized: "Instagram Reels")
        case .shorts: String(localized: "YouTube Shorts")
        case .youtube: String(localized: "YouTube · long-form")
        }
    }
}
