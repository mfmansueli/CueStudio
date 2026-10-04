//
//  SelectionAction.swift
//  Cue Studio
//

import Foundation

/// What the bar over a selection offers: four rewrites of just those words.
nonisolated enum SelectionAction: String, CaseIterable, Identifiable, Sendable {
    case rewrite, shorter, strongerHook, inMyVoice

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rewrite: String(localized: "✦ Rewrite")
        case .shorter: String(localized: "Shorter")
        case .strongerHook: String(localized: "Stronger hook")
        case .inMyVoice: String(localized: "In my voice")
        }
    }

    /// The candidate card's title.
    var title: String {
        switch self {
        case .rewrite: String(localized: "Rewrite")
        case .shorter: String(localized: "Shorter")
        case .strongerHook: String(localized: "Stronger hook")
        case .inMyVoice: String(localized: "In my voice")
        }
    }

    /// The tool that writes it (the same ones "Improve script" runs, on a piece of the text).
    var tool: ScriptTool {
        switch self {
        case .rewrite: .moreHuman
        case .shorter: .shorterAndDirect
        case .strongerHook: .moreEnergy
        case .inMyVoice: .inMyVoice
        }
    }
}
