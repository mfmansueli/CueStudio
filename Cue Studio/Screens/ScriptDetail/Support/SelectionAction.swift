//
//  SelectionAction.swift
//  Cue Studio
//

import Foundation

/// What the AI bar over a selection offers (v29 · A): Rewrite · Shorter · Punchier · More me, which the AI does to just those
/// words, and Cut, which only removes them (no AI).
nonisolated enum SelectionAction: String, CaseIterable, Identifiable, Sendable {
    case rewrite, shorter, punchier, moreMe, cut

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rewrite: String(localized: "Rewrite")
        case .shorter: String(localized: "Shorter")
        case .punchier: String(localized: "Punchier")
        case .moreMe: String(localized: "More me")
        case .cut: String(localized: "Cut")
        }
    }

    /// The tool that writes it (the same ones "Improve script" runs, on a piece of the text); nil for Cut.
    var tool: ScriptTool? {
        switch self {
        case .rewrite: .moreHuman
        case .shorter: .shorterAndDirect
        case .punchier: .moreEnergy
        case .moreMe: .inMyVoice
        case .cut: nil
        }
    }
}
