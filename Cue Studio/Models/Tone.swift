//
//  Tone.swift
//  Cue Studio
//

import Foundation

nonisolated enum Tone: String, Codable, CaseIterable, Identifiable, Sendable {
    case casual, energetic, expert, funny, premium, sincere, calm, direct

    var id: String { rawValue }

    /// Tones a creator can pick for their own voice in Creator DNA.
    static let creatorOptions: [Tone] = [.casual, .energetic, .expert, .funny]

    var label: String {
        switch self {
        case .casual: String(localized: "Casual")
        case .energetic: String(localized: "Energetic")
        case .expert: String(localized: "Expert")
        case .funny: String(localized: "Funny")
        case .premium: String(localized: "Premium")
        case .sincere: String(localized: "Sincere")
        case .calm: String(localized: "Calm")
        case .direct: String(localized: "Direct")
        }
    }
}
