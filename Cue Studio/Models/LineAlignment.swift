//
//  LineAlignment.swift
//  Cue Studio
//

import Foundation

/// How the lines of a text line up with each other: a text on the video, a caption or the prompter.
nonisolated enum LineAlignment: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = LineAlignment.center

    case leading, center, trailing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leading: String(localized: "Left")
        case .center: String(localized: "Center")
        case .trailing: String(localized: "Right")
        }
    }

    var systemImage: String {
        switch self {
        case .leading: "text.alignleft"
        case .center: "text.aligncenter"
        case .trailing: "text.alignright"
        }
    }
}
