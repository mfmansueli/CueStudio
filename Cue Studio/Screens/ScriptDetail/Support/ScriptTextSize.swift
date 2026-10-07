//
//  ScriptTextSize.swift
//  Cue Studio
//

import Foundation

/// How big the text is on the script page (its Aa button). It only changes the page; the prompter
/// has its own size.
nonisolated enum ScriptTextSize: Int, CaseIterable, Identifiable, Sendable {
    case small = 17
    case medium = 19
    case large = 22

    var id: Int { rawValue }

    /// Points at the default Dynamic Type size; the page scales them with the creator's setting.
    var points: Double { Double(rawValue) }
}
