//
//  AppSheet.swift
//  Cue Studio
//

import Foundation

/// Sheets presented over the tab bar.
enum AppSheet: Identifiable, Hashable {
    /// "+" on Scripts: write my own, or import.
    case newScript
    /// The Record tab: read from a recent script, start a new one, or record freestyle.
    case startRecording
    case importScript
    /// "Need an idea?" on the idea card: ideas from the creator's topics.
    case ideas
    /// "Format ⌄" on the idea card: how Cue builds the script.
    case format
    /// "For TikTok ⌄" on the idea card: the platform the idea is for.
    case createFor

    var id: String {
        switch self {
        case .newScript: "newScript"
        case .startRecording: "startRecording"
        case .importScript: "importScript"
        case .ideas: "ideas"
        case .format: "format"
        case .createFor: "createFor"
        }
    }
}
