//
//  TextShadowStyle.swift
//  Cue Studio
//

import Foundation

/// Text style › Color › Shadow: none, a soft shadow, or an outline (with its own drop shadow).
nonisolated enum TextShadowStyle: String, CaseIterable, Identifiable, Sendable {
    case none, soft, outline

    var id: String { rawValue }

    /// The style a text with these settings shows.
    init(hasShadow: Bool, hasOutline: Bool) {
        if hasOutline {
            self = .outline
        } else {
            self = hasShadow ? .soft : .none
        }
    }

    var hasShadow: Bool { self != .none }
    var hasOutline: Bool { self == .outline }

    var label: String {
        switch self {
        case .none: String(localized: "None")
        case .soft: String(localized: "Soft")
        case .outline: String(localized: "Outline")
        }
    }
}
