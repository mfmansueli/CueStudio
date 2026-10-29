//
//  MusicMood.swift
//  Cue Studio
//

import Foundation

/// How a library track feels, one per track: the music library's filters (`MusicLibraryFilter`).
nonisolated enum MusicMood: String, CaseIterable, Identifiable, Sendable {
    case calm, chill, focus, upbeat, playful, cinematic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calm: String(localized: "Calm")
        case .chill: String(localized: "Chill")
        case .focus: String(localized: "Focus")
        case .upbeat: String(localized: "Upbeat")
        case .playful: String(localized: "Playful")
        case .cinematic: String(localized: "Cinematic")
        }
    }
}
