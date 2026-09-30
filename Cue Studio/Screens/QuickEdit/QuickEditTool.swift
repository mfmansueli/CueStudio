//
//  QuickEditTool.swift
//  Cue Studio
//

import Foundation

/// A tool in Quick edit, grouped by what the creator wants to do (`QuickEditCategory`).
/// Transitions are picked on the cuts themselves, in the timeline; the cover is part of finishing.
enum QuickEditTool: String, CaseIterable, Identifiable {
    // Edit
    case trim, cleanUp, speed
    // Text
    case text, style
    // Captions
    case captions
    // Audio
    case audio, voiceOver
    // Media
    case media
    // Adjust
    case adjust, filters, crop
    // Finishing
    case cover

    var id: String { rawValue }

    var category: QuickEditCategory {
        switch self {
        case .trim, .cleanUp, .speed: .edit
        case .text, .style: .text
        case .captions: .captions
        case .audio, .voiceOver: .audio
        case .media: .media
        case .adjust, .filters, .crop: .adjust
        case .cover: .finish
        }
    }

    var label: String {
        switch self {
        case .trim: String(localized: "Trim")
        case .cleanUp: String(localized: "Clean Up")
        case .speed: String(localized: "Speed")
        case .text: String(localized: "Text")
        case .style: String(localized: "Presets")
        case .captions: String(localized: "Captions")
        case .audio: String(localized: "Voice")
        case .voiceOver: String(localized: "Voice-over")
        case .media: String(localized: "Media")
        case .adjust: String(localized: "Adjust")
        case .filters: String(localized: "Filters")
        case .crop: String(localized: "Crop")
        case .cover: String(localized: "Cover")
        }
    }

    var systemImage: String {
        switch self {
        case .trim: "timeline.selection"
        case .cleanUp: "sparkles"
        case .speed: "gauge.with.dots.needle.67percent"
        case .text: "textformat"
        case .style: "textformat.alt"
        case .captions: "captions.bubble"
        case .audio: "waveform"
        case .voiceOver: "mic"
        case .media: "photo.badge.plus"
        case .adjust: "sun.max"
        case .filters: "camera.filters"
        case .crop: "crop"
        case .cover: "photo.on.rectangle"
        }
    }

    /// Tools that show the edit on a timeline of their own and need the room.
    var usesTimeline: Bool {
        switch self {
        case .trim, .cleanUp, .text, .media, .voiceOver: true
        default: false
        }
    }
}
