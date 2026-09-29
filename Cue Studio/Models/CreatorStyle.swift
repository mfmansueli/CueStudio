//
//  CreatorStyle.swift
//  Cue Studio
//

import Foundation

/// A look for the whole video in one tap: how texts are set (font, weight, size, color,
/// background, place), the caption style and the filter. Applying it to one text only sets that
/// text; applying it to the project sets every text, the captions and the filter, and new texts
/// start from it.
nonisolated enum CreatorStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Clear and neutral: white semibold with a soft shadow.
    case clean
    /// Big, heavy capitals with an outline.
    case bold
    /// Quiet and elegant: light serif, smaller, a little lower.
    case minimal
    /// Made for vertical feeds: rounded, black on yellow.
    case social

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clean: String(localized: "Clean")
        case .bold: String(localized: "Bold")
        case .minimal: String(localized: "Minimal")
        case .social: String(localized: "Social")
        }
    }

    var detail: String {
        switch self {
        case .clean: String(localized: "Simple and clear")
        case .bold: String(localized: "Bigger, louder text")
        case .minimal: String(localized: "Quiet and elegant")
        case .social: String(localized: "Made for vertical feeds")
        }
    }

    var captionStyle: CaptionStyle {
        switch self {
        case .clean, .minimal: .classic
        case .bold: .bold
        case .social: .highlight
        }
    }

    var filter: VideoFilter {
        switch self {
        case .clean: .original
        case .bold, .social: .vivid
        case .minimal: .film
        }
    }

    /// Text sizes are the role's times this.
    var sizeScale: Double {
        switch self {
        case .clean: 1
        case .bold: 1.25
        case .minimal: 0.85
        case .social: 1.05
        }
    }

    /// Sets how `text` looks and where it sits; keeps what it says and when.
    func apply(to text: inout TextOverlay) {
        text.size = min(max(text.role.baseSize * sizeScale, TextOverlay.sizeRange.lowerBound), TextOverlay.sizeRange.upperBound)
        text.alignment = .center
        text.center = OverlayPoint(x: 0.5, y: position(for: text.role))
        switch self {
        case .clean:
            text.font = .classic
            text.weight = text.role == .subtitle || text.role == .callout ? .semibold : .bold
            text.isUppercase = false
            text.color = .white
            text.background = text.role == .callout ? .box : .none
            text.backgroundColor = .black
            text.hasShadow = true
            text.hasOutline = false
        case .bold:
            text.font = .classic
            text.weight = .heavy
            text.isUppercase = true
            text.color = text.role == .hook ? .yellow : .white
            text.background = .none
            text.backgroundColor = .black
            text.hasShadow = true
            text.hasOutline = true
        case .minimal:
            text.font = .serif
            text.weight = text.role == .title || text.role == .hook ? .semibold : .regular
            text.isUppercase = false
            text.color = .white
            text.background = .none
            text.backgroundColor = .black
            text.hasShadow = text.role != .callout
            text.hasOutline = false
            if text.role == .callout { text.background = .pill }
        case .social:
            text.font = .rounded
            text.weight = .heavy
            text.isUppercase = false
            text.color = text.role == .subtitle ? .white : .black
            text.background = text.role == .subtitle ? .none : .pill
            text.backgroundColor = text.role == .callout ? .white : .yellow
            text.hasShadow = text.role == .subtitle
            text.hasOutline = false
        }
    }

    /// Vertical center for a role in this style.
    func position(for role: TextOverlayRole) -> Double {
        switch self {
        case .minimal: min(role.defaultY + 0.04, 0.7)
        case .clean, .bold, .social: role.defaultY
        }
    }
}
