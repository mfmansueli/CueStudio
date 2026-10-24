//
//  CaptionCategory.swift
//  Cue Studio
//

import Foundation

/// The groups the caption catalogue is filed in (Caption style › Styles' filters), in the order they show.
nonisolated enum CaptionCategory: String, CaseIterable, Identifiable, Sendable {
    case cue, essentials, impact, editorial, colorful

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cue: String(localized: "Cue")
        case .essentials: String(localized: "Essentials")
        case .impact: String(localized: "Impact")
        case .editorial: String(localized: "Editorial")
        case .colorful: String(localized: "Colorful")
        }
    }
}
