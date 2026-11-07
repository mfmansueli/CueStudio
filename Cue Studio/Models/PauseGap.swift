//
//  PauseGap.swift
//  Cue Studio
//

import Foundation

/// Clean up › Pauses › "Gap left": how much silence a removed pause leaves between the words, half on each side of the cut. It
/// is its own choice, apart from "Pauses longer than" (which pauses are listed): one says which pauses count, the other how
/// much of each stays. Natural is what every cut left before the choice existed (`SilenceDetector.padding` on each side). The
/// three values are candidates the owner listens to before fixing them (D8, 07/11/2026).
nonisolated enum PauseGap: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = PauseGap.natural

    case tight, natural, relaxed

    var id: String { rawValue }

    /// Seconds of silence left where a pause was taken out.
    var seconds: TimeInterval {
        switch self {
        case .tight: 0.12
        case .natural: 0.24
        case .relaxed: 0.40
        }
    }

    /// pt "Curto · Natural · Longo" (owner, 07/11/2026): keys of their own, apart from other tools' "Tight" and "Natural".
    var label: String {
        switch self {
        case .tight: String(inInterfaceLanguage: LocalizedStringResource("pauseGap.tight", defaultValue: "Tight"))
        case .natural: String(inInterfaceLanguage: LocalizedStringResource("pauseGap.natural", defaultValue: "Natural"))
        case .relaxed: String(inInterfaceLanguage: LocalizedStringResource("pauseGap.relaxed", defaultValue: "Relaxed"))
        }
    }
}
