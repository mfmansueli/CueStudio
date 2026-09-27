//
//  PrompterSheet.swift
//  Cue Studio
//

import Foundation

/// Sheets presented over the prompter.
enum PrompterSheet: String, Identifiable {
    case display
    case camera
    /// Add a script to a freestyle recording.
    case addScript
    case importScript
    case generateScript

    var id: String { rawValue }
}
