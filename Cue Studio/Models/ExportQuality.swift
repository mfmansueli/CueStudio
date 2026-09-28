//
//  ExportQuality.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// "Quality" in Share to. 4K is part of Pro.
nonisolated enum ExportQuality: String, CaseIterable, Identifiable, Sendable {
    case hd1080, uhd4K

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hd1080: String(localized: "1080p")
        case .uhd4K: String(localized: "4K")
        }
    }

    /// Short side of the exported video in pixels.
    var shortSide: CGFloat {
        switch self {
        case .hd1080: 1080
        case .uhd4K: 2160
        }
    }

    var isPro: Bool { self == .uhd4K }
}
