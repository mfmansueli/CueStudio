//
//  ClipLookPart.swift
//  Cue Studio
//

import Foundation

/// What "Paste look" can take from a copied clip: its light and color (Adjust, with Skin Smoothing and Auto), its filter, its
/// background and its slow zoom.
nonisolated enum ClipLookPart: String, CaseIterable, Identifiable, Sendable {
    case adjust, filter, background, zoom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .adjust: String(localized: "Adjust")
        case .filter: String(localized: "Filter")
        case .background: String(localized: "Background")
        case .zoom: String(localized: "Zoom")
        }
    }
}
