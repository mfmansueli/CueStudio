//
//  ScrollMode.swift
//  Cue Studio
//

import Foundation

nonisolated enum ScrollMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Constant speed set by the user.
    case steady
    /// Scrolls while the microphone hears speech and waits during pauses.
    case voice

    var id: String { rawValue }

    var label: String {
        switch self {
        case .steady: String(localized: "Steady")
        case .voice: String(localized: "Voice Following")
        }
    }

    /// The word in the toolbar's switch ("Voice" | "Steady"); `label` is the full name for VoiceOver.
    var shortLabel: String {
        switch self {
        case .steady: String(localized: "Steady")
        case .voice: String(localized: "Voice")
        }
    }
}
