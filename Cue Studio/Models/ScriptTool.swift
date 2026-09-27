//
//  ScriptTool.swift
//  Cue Studio
//

import Foundation

/// One-tap tools offered above the keyboard while editing a script.
nonisolated enum ScriptTool: String, Codable, CaseIterable, Identifiable, Sendable {
    case newHooks
    case fitToTime
    case moreEnergy
    case fixGrammar
    case translate
    case strongerCTA
    case addDisclosure
    case moreHuman
    case lessDefensive
    case shorterAndDirect

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newHooks: String(localized: "3 new hooks")
        case .fitToTime: String(localized: "Fit to time")
        case .moreEnergy: String(localized: "More energy")
        case .fixGrammar: String(localized: "Fix grammar")
        case .translate: String(localized: "Translate")
        case .strongerCTA: String(localized: "Stronger CTA")
        case .addDisclosure: String(localized: "Add disclosure")
        case .moreHuman: String(localized: "More human")
        case .lessDefensive: String(localized: "Less defensive")
        case .shorterAndDirect: String(localized: "Shorter & direct")
        }
    }

    /// Tools that rewrite text need the on-device language model; the others are plain edits.
    var needsLanguageModel: Bool {
        switch self {
        case .newHooks, .addDisclosure: false
        default: true
        }
    }
}
