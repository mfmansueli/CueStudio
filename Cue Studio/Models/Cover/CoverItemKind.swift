//
//  CoverItemKind.swift
//  Cue Studio
//

import Foundation

/// A graphic on a cover: an arrow, a circle round something, a tag with a few words, the creator's @handle.
nonisolated enum CoverItemKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case arrow, circle, tag, handle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .arrow: String(localized: "Arrow")
        case .circle: String(localized: "Circle")
        case .tag: String(localized: "Tag")
        case .handle: String(localized: "@handle")
        }
    }

    var systemImage: String {
        switch self {
        case .arrow: "arrow.down.right"
        case .circle: "circle"
        case .tag: "tag"
        case .handle: "at"
        }
    }

    /// Its width at scale 1, as a share of the cover's width.
    var baseWidth: Double {
        switch self {
        case .arrow: 0.3
        case .circle: 0.42
        case .tag, .handle: 0.3
        }
    }

    /// Whether it carries words the creator writes.
    var hasText: Bool { self == .tag || self == .handle }

    var defaultColor: OverlayColor {
        switch self {
        case .arrow: .yellow
        case .circle: .red
        case .tag: .red
        case .handle: .white
        }
    }
}
