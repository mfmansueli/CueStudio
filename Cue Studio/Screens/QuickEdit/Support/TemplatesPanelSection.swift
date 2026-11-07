//
//  TemplatesPanelSection.swift
//  Cue Studio
//

import Foundation

/// The two panels the Templates panel is: the video templates (Cue's looks) and the creator's brand kits (their own), so a
/// template never reads as part of a kit. Each has its button on the bars, which opens it (no tabs between them, canvas 2 R3).
enum TemplatesPanelSection: String, CaseIterable, Identifiable {
    case templates, brand

    var id: String { rawValue }

    var label: String {
        switch self {
        case .templates: String(localized: "Templates")
        // Its own key: "Brand" is also the brand brief's field, which stays "Marca" in Portuguese where this panel is "Kit de marca".
        case .brand: String(inInterfaceLanguage: LocalizedStringResource("smart.brandKits", defaultValue: "Brand"))
        }
    }
}
