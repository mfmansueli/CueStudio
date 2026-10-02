//
//  ScriptTool+Presentation.swift
//  Cue Studio
//

import Foundation

/// How the editor shows each tool: an icon and a line saying what it does.
extension ScriptTool {
    var systemImage: String {
        switch self {
        case .inMyVoice: "mic"
        case .newHooks: "bolt"
        case .fitToTime: "clock"
        case .moreEnergy: "flame"
        case .fixGrammar: "checkmark"
        case .translate: "character.bubble"
        case .strongerCTA: "arrow.right"
        case .addDisclosure: "tag"
        case .moreHuman: "heart"
        case .lessDefensive: "shield"
        case .shorterAndDirect: "scissors"
        }
    }

    /// What the tool does, in a few words. "Fit to time" names the ideal length of the script's
    /// destination, which only the caller knows.
    func subtitle(idealRange: ClosedRange<TimeInterval>, platform: Platform) -> String {
        switch self {
        case .inMyVoice: String(localized: "Rewrite so it sounds like you")
        case .newHooks: String(localized: "Shorter openings to test")
        case .fitToTime:
            String(localized: "Ideal for \(platform.label): \(DurationText.clock(idealRange.lowerBound))–\(DurationText.clock(idealRange.upperBound))")
        case .moreEnergy: String(localized: "Punchier lines, same message")
        case .fixGrammar: String(localized: "Typos and punctuation")
        case .translate: String(localized: "Saves a translated copy")
        case .strongerCTA: String(localized: "A clearer next step")
        case .addDisclosure: String(localized: "Paid-partnership line up front")
        case .moreHuman: String(localized: "Warmer, less scripted")
        case .lessDefensive: String(localized: "Removes excuses and “but”s")
        case .shorterAndDirect: String(localized: "Cuts filler words")
        }
    }
}
