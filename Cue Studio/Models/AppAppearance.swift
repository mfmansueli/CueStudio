//
//  AppAppearance.swift
//  Cue Studio
//

import SwiftUI

/// How Cue's own screens look (Settings › Appearance): the way the iPhone is set, or always light
/// or dark. The camera, the prompter, the take review and the editor stay dark in all three: they
/// are seen over video (`videoContext()`).
enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    /// Nil follows the iPhone.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String {
        switch self {
        case .system: String(localized: "Automatic")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}
