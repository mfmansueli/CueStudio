//
//  AutoEditStep.swift
//  Cue Studio
//

import Foundation

/// A step of Auto edit, in the order it runs: the speech cleaned up, captions from the voice, zoom on lines with a clear number,
/// value or name. Nothing else: no music, effects, styles or cuts the creator didn't choose (plan §14).
nonisolated enum AutoEditStep: String, Codable, CaseIterable, Identifiable, Sendable {
    case speech, captions, zoom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speech: String(localized: "Clean up speech")
        case .captions: String(localized: "Captions")
        case .zoom: String(localized: "Zoom on key lines")
        }
    }
}
