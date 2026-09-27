//
//  AppSheet.swift
//  Cue Studio
//

import Foundation

/// Sheets presented over the tab bar.
enum AppSheet: String, Identifiable {
    /// "What are you recording?"
    case newScript
    case importScript
    case generateScript

    var id: String { rawValue }
}
