//
//  PrompterTextColor.swift
//  Cue Studio
//

import Foundation

/// Text colors offered for the prompter. Stored as hex so the model stays free of SwiftUI.
nonisolated enum PrompterTextColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case white = "#FFFFFF"
    case cream = "#F3E9D2"
    case yellow = "#FFD60A"
    case cyan = "#7FDBFF"
    case green = "#A6F28B"

    var id: String { rawValue }

    var hex: String { rawValue }

    var label: String {
        switch self {
        case .white: String(localized: "White")
        case .cream: String(localized: "Warm white")
        case .yellow: String(localized: "Yellow")
        case .cyan: String(localized: "Cyan")
        case .green: String(localized: "Mint")
        }
    }
}
