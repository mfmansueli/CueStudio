//
//  MediaLayout.swift
//  Cue Studio
//

import Foundation

/// How a photo or video laid over the take (B-roll) takes the frame.
nonisolated enum MediaLayout: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Covers the whole frame, cropped to fill it: the classic cutaway.
    case fullFrame
    /// A window over the take, placed and sized by the creator.
    case window

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fullFrame: String(localized: "Full screen")
        case .window: String(localized: "Window")
        }
    }
}
