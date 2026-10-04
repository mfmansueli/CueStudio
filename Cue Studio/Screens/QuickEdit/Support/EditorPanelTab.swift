//
//  EditorPanelTab.swift
//  Cue Studio
//

import Foundation

/// The tabs of the styling panels: Text style (Presets, Font, Color, Motion), Caption style
/// (Presets, Reveal, Position, Font) and Cover (Frame, Text, Elements, Look).
enum EditorPanelTab: String, CaseIterable, Identifiable {
    case presets, font, color, motion, reveal, position
    case frame, coverText, elements, look

    var id: String { rawValue }

    static let textStyle: [EditorPanelTab] = [.presets, .font, .color, .motion]
    static let captionStyle: [EditorPanelTab] = [.presets, .reveal, .position, .font]
    static let cover: [EditorPanelTab] = [.frame, .coverText, .elements, .look]

    /// The tab a panel opens on.
    static func first(for panel: EditorPanel) -> EditorPanelTab { panel == .cover ? .frame : .presets }

    var label: String {
        switch self {
        case .presets: String(localized: "Presets")
        case .font: String(localized: "Font")
        case .color: String(localized: "Color")
        case .motion: String(localized: "Motion")
        case .reveal: String(localized: "Reveal")
        case .position: String(localized: "Position")
        case .frame: String(localized: "Frame")
        case .coverText: String(localized: "Text")
        case .elements: String(localized: "Elements")
        case .look: String(localized: "Look")
        }
    }
}
