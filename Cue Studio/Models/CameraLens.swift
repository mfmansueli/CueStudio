//
//  CameraLens.swift
//  Cue Studio
//

import Foundation

nonisolated enum CameraLens: String, Codable, CaseIterable, Identifiable, Sendable {
    case front, wide, ultraWide, telephoto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .front: String(localized: "Front")
        case .wide: String(localized: "Back · Wide")
        case .ultraWide: String(localized: "Back · Ultra Wide")
        case .telephoto: String(localized: "Back · Telephoto")
        }
    }

    var detail: String {
        switch self {
        case .front: String(localized: "TrueDepth")
        case .wide: "1×"
        case .ultraWide: "0.5×"
        case .telephoto: String(localized: "Zoom")
        }
    }

    var isFront: Bool { self == .front }
}
