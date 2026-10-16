//
//  EditorPanelTab.swift
//  Cue Studio
//

import Foundation

/// The tabs of the styling panels: Text style (Presets, Font, Color, Motion) and Caption style
/// (Presets, Reveal, Position, Font).
enum EditorPanelTab: String, CaseIterable, Identifiable {
    case presets, font, color, motion, reveal, position

    var id: String { rawValue }

    static let textStyle: [EditorPanelTab] = [.presets, .font, .color, .motion]
    static let captionStyle: [EditorPanelTab] = [.presets, .reveal, .position, .font]

    /// The tab a panel opens on.
    static func first(for panel: EditorPanel) -> EditorPanelTab { .presets }

    var label: String {
        switch self {
        case .presets: String(localized: "Presets")
        case .font: String(localized: "Font")
        case .color: String(localized: "Color")
        case .motion: String(localized: "Motion")
        case .reveal: String(localized: "Reveal")
        case .position: String(localized: "Position")
        }
    }
}
