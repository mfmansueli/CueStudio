//
//  CropFit.swift
//  Cue Studio
//

import Foundation

/// How the recording fills the format picked in Crop.
nonisolated enum CropFit: String, Codable, CaseIterable, Identifiable, Sendable {
    /// The whole frame filled: what doesn't fit is cropped (as before Fit existed).
    case fill
    /// The whole recording shows, with black bars where the format is wider or taller.
    case fit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fill: String(localized: "Fill")
        case .fit: String(localized: "Fit")
        }
    }
}
