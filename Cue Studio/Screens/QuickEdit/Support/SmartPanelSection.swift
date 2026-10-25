//
//  SmartPanelSection.swift
//  Cue Studio
//

import Foundation

/// The parts of ✦ Smart: the one-tap tools (captions, pauses, Studio Voice, Auto adjust, Background), the video templates
/// (Cue's looks) and the creator's brand kits (their own), each a category of its own so a template never reads as part of a
/// tool.
enum SmartPanelSection: String, CaseIterable, Identifiable {
    case tools, templates, brand

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tools: String(localized: "Tools", comment: "✦ Smart tab: the one-tap tools")
        case .templates: String(localized: "Templates")
        // Its own key: "Brand" is also the brand brief's field, which stays "Marca" in Portuguese where this tab is "Kit de marca".
        case .brand: String(inInterfaceLanguage: LocalizedStringResource("smart.brandKits", defaultValue: "Brand"))
        }
    }
}
