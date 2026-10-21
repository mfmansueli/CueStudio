//
//  HumorLevel.swift
//  Cue Studio
//

import Foundation

nonisolated enum HumorLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Not `none`: that name reads as an absent value (`humor: .none`).
    case noHumor = "none", little, lot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noHumor: String(localized: "None")
        case .little: String(localized: "A little")
        case .lot: String(localized: "A lot")
        }
    }

    /// What the AI reads (English, whatever the interface language is).
    var promptName: String {
        switch self {
        case .noHumor: "none, no jokes"
        case .little: "a little"
        case .lot: "a lot"
        }
    }
}
