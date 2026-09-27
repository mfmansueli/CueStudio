//
//  QuickEditTool.swift
//  Cue Studio
//

import Foundation

/// The six tools along the bottom of Quick edit.
enum QuickEditTool: String, CaseIterable, Identifiable {
    case trim, audio, adjust, filters, crop, captions

    var id: String { rawValue }

    var label: String {
        switch self {
        case .trim: String(localized: "Trim")
        case .audio: String(localized: "Audio")
        case .adjust: String(localized: "Adjust")
        case .filters: String(localized: "Filters")
        case .crop: String(localized: "Crop")
        case .captions: String(localized: "Captions")
        }
    }

    var systemImage: String {
        switch self {
        case .trim: "timeline.selection"
        case .audio: "speaker.wave.2"
        case .adjust: "sun.max"
        case .filters: "camera.filters"
        case .crop: "crop"
        case .captions: "captions.bubble"
        }
    }
}
