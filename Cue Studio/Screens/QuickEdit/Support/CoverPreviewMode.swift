//
//  CoverPreviewMode.swift
//  Cue Studio
//

import Foundation

/// How Cover's preview shows the cover: alone (the feed), or in a profile's grid among the series.
enum CoverPreviewMode: String, CaseIterable, Identifiable {
    case feed, grid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .feed: String(localized: "Feed")
        case .grid: String(localized: "Profile grid")
        }
    }
}
