//
//  CaptionStyle.swift
//  Cue Studio
//

import Foundation

/// How burned-in captions look.
nonisolated enum CaptionStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// White on a dark box.
    case classic
    /// Big, bold, uppercase, with a shadow.
    case bold
    /// Black on the accent yellow.
    case highlight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic: String(localized: "Classic")
        case .bold: String(localized: "Bold")
        case .highlight: String(localized: "Highlight")
        }
    }
}
