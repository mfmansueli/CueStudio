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

    /// The name in the interface's language.
    var name: String { name(in: nil) }

    /// The name in `language` (a script's own, for cues Cue writes into it), the interface's when nil.
    func name(in language: CueLanguage?) -> String {
        switch self {
        case .pause: String(localized: "pause", writtenIn: language)
        case .beat: String(localized: "beat", writtenIn: language)
        case .smile: String(localized: "smile", writtenIn: language)
        case .lookAtCamera: String(localized: "look at camera", writtenIn: language)
        case .confident: String(localized: "confident", writtenIn: language)
        case .slowDown: String(localized: "slow down", writtenIn: language)
        case .breathe: String(localized: "breathe", writtenIn: language)
        case .showProduct: String(localized: "show product", writtenIn: language)
        case .demo: String(localized: "demo", writtenIn: language)
        case .emphasis: String(localized: "emphasis", writtenIn: language)
        }
    }
}
