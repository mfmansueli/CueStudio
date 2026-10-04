//
//  PrompterSettingsSection.swift
//  Cue Studio
//

import Foundation

/// The chips under the preview on Settings › Prompter: each one scrolls to its rows.
enum PrompterSettingsSection: String, CaseIterable, Identifiable {
    case reading, text, line, window, safeZones

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reading: String(localized: "Reading")
        case .text: String(localized: "Text")
        case .line: String(localized: "Line")
        case .window: String(localized: "Window")
        case .safeZones: String(localized: "Safe zones")
        }
    }
}
