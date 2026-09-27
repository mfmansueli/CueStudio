//
//  CaptionPosition.swift
//  Cue Studio
//

import Foundation

nonisolated enum CaptionPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case top, middle, bottom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .top: String(localized: "Top")
        case .middle: String(localized: "Middle")
        case .bottom: String(localized: "Bottom")
        }
    }

    /// Vertical center of the caption as a fraction of the frame height.
    var verticalFraction: Double {
        switch self {
        case .top: 0.12
        case .middle: 0.46
        case .bottom: 0.76
        }
    }
}
