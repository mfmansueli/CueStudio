//
//  PrompterSheet.swift
//  Cue Studio
//

import Foundation

/// Sheets presented over the prompter.
enum PrompterSheet: Identifiable, Hashable {
    case display
    case camera
    /// Add a script to a freestyle recording: a recent one or a new one.
    case addScript
    /// "New script", without the blank page (there is no editor over the camera).
    case newScript
    case importScript
    case generateScript(GenerateTab)

    var id: String {
        switch self {
        case .display: "display"
        case .camera: "camera"
        case .addScript: "addScript"
        case .newScript: "newScript"
        case .importScript: "importScript"
        case .generateScript(let tab): "generateScript.\(tab.rawValue)"
        }
    }
}
