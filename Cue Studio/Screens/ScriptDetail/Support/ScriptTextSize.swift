//
//  ScriptTextSize.swift
//  Cue Studio
//

import Foundation

/// How big the text is while writing (Options › Text size). It only changes the editor; the
/// prompter has its own size.
nonisolated enum ScriptTextSize: Int, CaseIterable, Identifiable, Sendable {
    case small = 17
    case medium = 19
    case large = 22

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .small: String(localized: "Small")
        case .medium: String(localized: "Medium")
        case .large: String(localized: "Large")
        }
    }

    /// Points at the default Dynamic Type size; the editor scales them with the creator's setting.
    var points: Double { Double(rawValue) }
}
