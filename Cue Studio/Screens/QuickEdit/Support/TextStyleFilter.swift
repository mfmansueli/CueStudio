//
//  TextStyleFilter.swift
//  Cue Studio
//

import Foundation

/// What Text style › Styles shows: every style (the creator's, the six that play their way in, Cue's), only the animated ones,
/// or only the creator's. Animated was a tab of its own; it's a filter of the styles, as they're ready-made looks like the others
/// (owner, canvas 2 R3 and F3, 07/11/2026).
enum TextStyleFilter: String, CaseIterable, Identifiable {
    case all, animated, mine

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: String(localized: "All")
        // Titles that move (pt "Animados").
        case .animated: String(inInterfaceLanguage: LocalizedStringResource("textStyle.animated", defaultValue: "Animated"))
        case .mine: String(localized: "Mine")
        }
    }
}
