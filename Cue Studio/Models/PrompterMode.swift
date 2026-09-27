//
//  PrompterMode.swift
//  Cue Studio
//

import Foundation

nonisolated enum PrompterMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Prompter over the camera: read while recording yourself.
    case selfie
    /// Full-screen prompter only, for rigs and beam-splitter glass.
    case studio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .selfie: String(localized: "Selfie")
        case .studio: String(localized: "Studio")
        }
    }
}
