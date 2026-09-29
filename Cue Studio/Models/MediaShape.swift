//
//  MediaShape.swift
//  Cue Studio
//

import Foundation

/// The window's shape: the media's own, or a crop of it.
nonisolated enum MediaShape: String, Codable, CaseIterable, Identifiable, Sendable {
    case original, square, portrait, landscape

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: String(localized: "Original")
        case .square: "1:1"
        case .portrait: "4:5"
        case .landscape: "16:9"
        }
    }

    /// Width over height, or nil to keep the media's own.
    var aspect: Double? {
        switch self {
        case .original: nil
        case .square: 1
        case .portrait: 4.0 / 5.0
        case .landscape: 16.0 / 9.0
        }
    }
}
