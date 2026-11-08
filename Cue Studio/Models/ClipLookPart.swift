//
//  ClipLookPart.swift
//  Cue Studio
//

import Foundation

/// What "Paste look" can take from a copied clip: its light and color (Adjust, with Auto), its Skin (smoothing with its texture
/// and engine, face light, less shine), its filter, its background and its slow zoom. Each goes, or stays, on its own.
nonisolated enum ClipLookPart: String, Codable, CaseIterable, Identifiable, Sendable {
    case adjust, skin, filter, background, zoom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .adjust: String(localized: "Adjust")
        case .skin: String(localized: "Skin", comment: "Video editor toolbar: opens Skin (smooths the skin, lights the face, takes off shine)")
        case .filter: String(localized: "Filter")
        case .background: String(localized: "Background")
        case .zoom: String(localized: "Zoom")
        }
    }
}
