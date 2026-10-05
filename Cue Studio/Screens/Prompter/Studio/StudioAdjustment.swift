//
//  StudioAdjustment.swift
//  Cue Studio
//

import Foundation

/// What Studio's bar lets the creator tune with one slider while reading: the size of the words, where the reading line sits on the
/// screen (for the eyes) and the room left on each side. Speed has its own slider on the bar.
enum StudioAdjustment: String, CaseIterable, Identifiable {
    case size, line, margin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .size: String(localized: "Size")
        case .line: String(localized: "Line")
        case .margin: String(localized: "Margin")
        }
    }

    var icon: CueIcon {
        switch self {
        case .size: .textSize
        case .line: .readingLine
        case .margin: .margins
        }
    }

    /// What the slider says it moves, for VoiceOver.
    var spokenName: String {
        switch self {
        case .size: String(localized: "Text size")
        case .line: String(localized: "Reading line")
        case .margin: String(localized: "Margins")
        }
    }
}
