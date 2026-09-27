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

    var id: String {
        switch self {
        case .newScript: "newScript"
        case .startRecording: "startRecording"
        case .importScript: "importScript"
        case .generateScript(let tab): "generateScript.\(tab.rawValue)"
        }
    }
}
