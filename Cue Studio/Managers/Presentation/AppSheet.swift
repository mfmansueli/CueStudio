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
    /// The empty Scripts screen's idea card: a roomy place to type or dictate the idea, opened from
    /// the field (keyboard) or from the microphone (`dictating`). The text is the card's draft.
    case composeIdea(dictating: Bool)
    /// Sends the card's draft (`IdeaDraftService`) to the generation sheet, which writes it as soon as
    /// it shows, using the same flow as Generate › Prompt.
    case generateIdea

    var id: String {
        switch self {
        case .newScript: "newScript"
        case .startRecording: "startRecording"
        case .importScript: "importScript"
        case .generateScript(let tab): "generateScript.\(tab.rawValue)"
        case .composeIdea: "composeIdea"
        case .generateIdea: "generateIdea"
        }
    }
}

extension AppSheet {
    /// The composer of the idea card: it owns the microphone while it is shown.
    var isIdeaComposer: Bool {
        if case .composeIdea = self { true } else { false }
    }
}
