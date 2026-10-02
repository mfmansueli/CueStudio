//
//  AppSheet.swift
//  Cue Studio
//

import Foundation

/// Sheets presented over the tab bar.
enum AppSheet: Identifiable, Hashable {
    /// "+" on Scripts: prompt, write, import, themes or formats.
    case newScript
    /// The Record tab: read from a recent script, start a new one, or record freestyle.
    case startRecording
    case importScript
    case generateScript(GenerateTab)
    /// The idea card's arrow: Generate with AI opens with the card's draft (`IdeaDraftService`) filled
    /// in, to confirm platform, length and voice. It writes only when its own button is tapped.
    case generateIdea

    var id: String {
        switch self {
        case .newScript: "newScript"
        case .startRecording: "startRecording"
        case .importScript: "importScript"
        case .generateScript(let tab): "generateScript.\(tab.rawValue)"
        case .generateIdea: "generateIdea"
        }
    }
}
