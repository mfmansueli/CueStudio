//
//  TypePreset.swift
//  Cue Studio
//

import Foundation

/// Type presets for texts and captions. Each one is set twice: for short texts read at a glance
/// (titles, hooks, callouts) and for captions read line after line. System fonts only, so every
/// language the interface speaks (Arabic, Hindi, Thai, Japanese…) has its letters, and right to
/// left text flows the right way.
///
/// A preset is type only: filters, Adjust and the cover stay as they are.
nonisolated enum TypePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Cue's own: clear, confident, a touch of yellow.
    case cue
    /// Heavy capitals with an outline: loud and short.
    case impact
    /// A serif with room to breathe.
    case editorial
    /// Rounded and friendly.
    case soft
    /// Light and spaced out.
    case minimal
    /// Words on a solid tag.
    case label
    /// Rounded, heavy, colorful.
    case pop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cue: String(localized: "Cue")
        case .impact: String(localized: "Impact")
        case .editorial: String(localized: "Editorial")
        case .soft: String(localized: "Soft")
        case .minimal: String(localized: "Minimal")
        case .label: String(localized: "Label")
        case .pop: String(localized: "Pop")
        }
    }

    var detail: String {
        switch self {
        case .cue: String(localized: "Clear and confident")
        case .impact: String(localized: "Loud, bold capitals")
        case .editorial: String(localized: "Calm, magazine serif")
        case .soft: String(localized: "Rounded and friendly")
        case .minimal: String(localized: "Light, lots of air")
        case .label: String(localized: "Words on a tag")
        case .pop: String(localized: "Round, heavy, colorful")
        }
    }

    /// The look for `use`.
    func look(for use: TextUse) -> TextLook {
        switch use {
        case .title: titleLook
        case .caption: captionLook
        }
    }

    private var titleLook: TextLook {
        switch self {
        case .cue:
            TextLook(font: .classic, weight: .heavy, sizeScale: 1.05, tracking: -0.01, color: .white, hasShadow: true)
        case .impact:
            TextLook(font: .classic, weight: .heavy, sizeScale: 1.25, tracking: -0.02, isUppercase: true, color: .white, hasShadow: true, hasOutline: true)
        case .editorial:
            TextLook(font: .serif, weight: .semibold, sizeScale: 1, tracking: 0, color: .white, hasShadow: true, verticalOffset: 0.02)
        case .soft:
            TextLook(
                font: .rounded, weight: .bold, sizeScale: 0.95, color: .black,
                background: .pill, backgroundColor: .white, backgroundOpacity: 0.92, hasShadow: false
            )
        case .minimal:
            TextLook(font: .classic, weight: .regular, sizeScale: 0.8, tracking: 0.12, isUppercase: true, color: .white, hasShadow: true, verticalOffset: 0.03)
        case .label:
            TextLook(
                font: .classic, weight: .bold, sizeScale: 0.85, tracking: 0.04, isUppercase: true, color: .black,
                background: .box, backgroundColor: .yellow, hasShadow: false
            )
        case .pop:
            TextLook(font: .rounded, weight: .heavy, sizeScale: 1.15, color: .yellow, hasShadow: true, hasOutline: true)
        }
    }

    /// Captions stay under 1.2× so a line of five words fits, and every one keeps a shadow, an
    /// outline or a fill to read over any background.
    private var captionLook: TextLook {
        switch self {
        case .cue:
            TextLook(
                font: .classic, weight: .semibold, sizeScale: 1, color: .white,
                background: .box, backgroundColor: .black, backgroundOpacity: 0.62, hasShadow: false
            )
        case .impact:
            TextLook(font: .classic, weight: .heavy, sizeScale: 1.15, isUppercase: true, color: .white, hasShadow: true, hasOutline: true)
        case .editorial:
            TextLook(font: .serif, weight: .regular, sizeScale: 1.05, color: .white, hasShadow: true)
        case .soft:
            TextLook(
                font: .rounded, weight: .semibold, sizeScale: 1, color: .white,
                background: .pill, backgroundColor: .black, backgroundOpacity: 0.45, hasShadow: false
            )
        case .minimal:
            TextLook(font: .classic, weight: .regular, sizeScale: 0.9, tracking: 0.02, color: .white, hasShadow: true)
        case .label:
            TextLook(font: .classic, weight: .bold, sizeScale: 0.95, color: .black, background: .box, backgroundColor: .white, hasShadow: false)
        case .pop:
            TextLook(font: .rounded, weight: .heavy, sizeScale: 1.1, color: .white, hasShadow: true, hasOutline: true)
        }
    }
}
