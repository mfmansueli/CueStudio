//
//  CoverElement.swift
//  Cue Studio
//

import Foundation

/// The little extras drawn on a cover (Cover › Elements).
nonisolated enum CoverElement: String, Codable, CaseIterable, Identifiable, Sendable {
    case arrow, circle, series, badge, handle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .arrow: String(localized: "Arrow")
        case .circle: String(localized: "Circle")
        case .series: String(localized: "Series tag")
        case .badge: String(localized: "Badge")
        case .handle: String(localized: "@handle")
        }
    }

    var glyph: String {
        switch self {
        case .arrow: "↘"
        case .circle: "◯"
        case .series: "EP"
        case .badge: "NEW"
        case .handle: "@"
        }
    }
}
