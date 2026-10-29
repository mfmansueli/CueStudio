//
//  MusicDuckPauses.swift
//  Cue Studio
//

import Foundation

/// What music lowered under the voice does in the pauses between sentences: stays low through them (a calm bed that never
/// swells between words; quiet up to about three seconds keeps it down), or comes back up as soon as the pause is long
/// enough to hear it (about a second), for edits where the music carries the moments between lines. The way in and out is the
/// same smooth curve in both (`MusicEnvelope.Timing`).
nonisolated enum MusicDuckPauses: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = MusicDuckPauses.staysLow

    case staysLow, comesBack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .staysLow: String(localized: "Stays low")
        case .comesBack: String(localized: "Comes back up")
        }
    }
}
