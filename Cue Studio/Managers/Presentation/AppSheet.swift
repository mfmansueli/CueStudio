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
    /// The empty Scripts screen's idea: the generation sheet opens with the text (and the kind of
    /// video) and writes it, using the same flow as Generate › Prompt.
    case generateIdea(ScriptIdeaSeed)

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
