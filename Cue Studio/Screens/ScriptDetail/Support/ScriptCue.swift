//
//  ScriptCue.swift
//  Cue Studio
//

import Foundation

/// The stage directions the Cues panel offers: written in square brackets in the script, shown as
/// tags, not read aloud. Named in the interface's language.
nonisolated enum ScriptCue: CaseIterable, Identifiable, Sendable {
    case pause, beat, smile, lookAtCamera, confident, slowDown, breathe, showProduct, demo, emphasis

    var id: Self { self }

    /// The four on the bar above the keyboard (v29 · 4.2).
    static let bar: [ScriptCue] = [.pause, .smile, .emphasis, .lookAtCamera]

    var name: String {
        switch self {
        case .pause: String(localized: "pause")
        case .beat: String(localized: "beat")
        case .smile: String(localized: "smile")
        case .lookAtCamera: String(localized: "look at camera")
        case .confident: String(localized: "confident")
        case .slowDown: String(localized: "slow down")
        case .breathe: String(localized: "breathe")
        case .showProduct: String(localized: "show product")
        case .demo: String(localized: "demo")
        case .emphasis: String(localized: "emphasis")
        }
    }
}
