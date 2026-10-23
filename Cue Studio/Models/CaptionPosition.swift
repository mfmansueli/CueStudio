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

    /// Vertical center of the caption as a fraction of the frame height, from the top: where Position puts the captions and
    /// where a drag sticks them (`QuickEditViewModel.captionStops`). Middle is the frame's middle, on the preview's guide.
    var verticalFraction: Double {
        switch self {
        case .top: 0.16
        case .middle: 0.5
        case .bottom: 0.76
        }
    }
}
