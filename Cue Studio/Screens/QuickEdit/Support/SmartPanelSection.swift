//
//  SmartPanelSection.swift
//  Cue Studio
//

import Foundation

/// The two parts of ✦ Smart: the one-tap tools (captions, pauses, Studio Voice, Auto adjust, Background) and the video
/// templates, each a category of its own so a template never reads as part of a tool.
enum SmartPanelSection: String, CaseIterable, Identifiable {
    case tools, templates

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tools: String(localized: "Tools", comment: "✦ Smart tab: the one-tap tools")
        case .templates: String(localized: "Templates")
        }
    }
}
