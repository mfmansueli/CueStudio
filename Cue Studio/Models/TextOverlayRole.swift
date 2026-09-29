//
//  TextOverlayRole.swift
//  Cue Studio
//

import Foundation

/// What a text on the video is for. Each starts with its own size, place and length; a creator
/// style decides the rest.
nonisolated enum TextOverlayRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case title, subtitle, hook, callout

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: String(localized: "Title")
        case .subtitle: String(localized: "Subtitle")
        case .hook: String(localized: "Hook")
        case .callout: String(localized: "Callout")
        }
    }

    /// What a new text says until the creator types.
    var placeholder: String {
        switch self {
        case .title: String(localized: "Your title")
        case .subtitle: String(localized: "A line to explain it")
        case .hook: String(localized: "Wait for it…")
        case .callout: String(localized: "Link in bio")
        }
    }

    var systemImage: String {
        switch self {
        case .title: "textformat.size.larger"
        case .subtitle: "textformat.size.smaller"
        case .hook: "bolt.fill"
        case .callout: "text.bubble"
        }
    }

    /// Size in points on a 402-point-wide frame, before the style's scale.
    var baseSize: Double {
        switch self {
        case .title: 30
        case .subtitle: 19
        case .hook: 32
        case .callout: 18
        }
    }

    /// How long it stays on screen when added.
    var defaultDuration: TimeInterval {
        switch self {
        case .title, .hook: 3
        case .subtitle: 4
        case .callout: 2.5
        }
    }

    /// Vertical center as a fraction of the frame, from the top: titles and hooks high, clear of
    /// the face; callouts low, above the platforms' captions and buttons.
    var defaultY: Double {
        switch self {
        case .title: 0.2
        case .subtitle: 0.3
        case .hook: 0.16
        case .callout: 0.64
        }
    }
}
