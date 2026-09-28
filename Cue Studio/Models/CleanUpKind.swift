//
//  CleanUpKind.swift
//  Cue Studio
//

import Foundation

/// What Clean Up can find in a take. Pauses come from the take's loudness; filler words and
/// retakes will come from the transcript with word timings (`TimedWord`).
nonisolated enum CleanUpKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case pause, filler, retake

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pause: String(localized: "Pause")
        case .filler: String(localized: "Filler word")
        case .retake: String(localized: "Possible retake")
        }
    }
}
