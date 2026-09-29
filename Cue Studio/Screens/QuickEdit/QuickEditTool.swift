//
//  QuickEditTool.swift
//  Cue Studio
//

import Foundation

/// Quick edit's tools, in the order they show inside their category (`QuickEditCategory`).
enum QuickEditTool: String, CaseIterable, Identifiable {
    // Edit
    case trim, cleanUp, removePauses, speed
    // Add
    case text, media, voiceOver
    // Polish
    case style, audio, adjust, filters, crop, transitions
    // One each
    case captions, cover

    var id: String { rawValue }

    var category: QuickEditCategory {
        switch self {
        case .trim, .cleanUp, .removePauses, .speed: .edit
        case .text, .media, .voiceOver: .add
        case .style, .audio, .adjust, .filters, .crop, .transitions: .polish
        case .captions: .captions
        case .cover: .cover
        }
    }

    var label: String {
        switch self {
        case .trim: String(localized: "Trim")
        case .cleanUp: String(localized: "Clean Up")
        case .removePauses: String(localized: "Remove Pauses")
        case .speed: String(localized: "Speed")
        case .text: String(localized: "Text")
        case .media: String(localized: "Media")
        case .voiceOver: String(localized: "Voice-over")
        case .style: String(localized: "Style")
        case .audio: String(localized: "Audio")
        case .adjust: String(localized: "Adjust")
        case .filters: String(localized: "Filters")
        case .crop: String(localized: "Crop")
        case .transitions: String(localized: "Transitions")
        case .captions: String(localized: "Captions")
        case .cover: String(localized: "Cover")
        }
    }

    var systemImage: String {
        switch self {
        case .trim: "timeline.selection"
        case .cleanUp: "sparkles"
        case .removePauses: "waveform.badge.minus"
        case .speed: "gauge.with.dots.needle.67percent"
        case .text: "textformat"
        case .media: "photo.badge.plus"
        case .voiceOver: "mic"
        case .style: "paintpalette"
        case .audio: "speaker.wave.2"
        case .adjust: "sun.max"
        case .filters: "camera.filters"
        case .crop: "crop"
        case .transitions: "square.on.square.dashed"
        case .captions: "captions.bubble"
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
