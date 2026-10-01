//
//  TypePreset.swift
//  Cue Studio
//

import Foundation

/// Type presets for texts (and for captions when a text's look goes on them too). The editor's
/// eight, from the v10 design, each readable over any video with a solid background, a soft shadow
/// or an outline: Cue, Editorial, Bold, Pop, Soft, Minimal, Label and Paper. Impact stays for
/// texts styled with it before.
///
/// A preset is type only: filters, Adjust and the cover stay as they are.
nonisolated enum TypePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    /// DM Sans heavy, black on a yellow box.
    case cue
    /// Heavy capitals with an outline (before the v10 editor).
    case impact
    /// DM Serif Display with a soft shadow.
    case editorial
    /// Space Grotesk bold capitals with an outline.
    case bold
    /// Space Grotesk bold in yellow, outlined.
    case pop
    /// DM Sans bold, dark on a white pill.
    case soft
    /// DM Sans medium, small, with a soft shadow.
    case minimal
    /// Space Grotesk capitals, widely spaced, on a dark tag.
    case label
    /// DM Serif Display, dark on paper.
    case paper

    var id: String { rawValue }

    /// The presets the editor offers, in order.
    static let editorPresets: [TypePreset] = [.cue, .editorial, .bold, .pop, .soft, .minimal, .label, .paper]

    var label: String {
        switch self {
        case .cue: String(localized: "Cue")
        case .impact: String(localized: "Impact")
        case .editorial: String(localized: "Editorial")
        case .bold: String(localized: "Bold")
        case .soft: String(localized: "Soft")
        case .minimal: String(localized: "Minimal")
        case .label: String(localized: "Label")
        case .pop: String(localized: "Pop")
        case .paper: String(localized: "Paper")
        }
    }

    var detail: String {
        switch self {
        case .cue: String(localized: "Clear and confident")
        case .impact: String(localized: "Loud, bold capitals")
        case .editorial: String(localized: "Calm, magazine serif")
        case .bold: String(localized: "Outlined capitals")
        case .soft: String(localized: "Rounded and friendly")
        case .minimal: String(localized: "Light, lots of air")
        case .label: String(localized: "Words on a tag")
        case .pop: String(localized: "Yellow, outlined")
        case .paper: String(localized: "Serif on paper")
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
            TextLook(
                font: .dmSans, weight: .heavy, sizeScale: 1, tracking: -0.01, color: .black,
                background: .box, backgroundColor: .yellow, hasShadow: false
            )
        case .impact:
            TextLook(font: .classic, weight: .heavy, sizeScale: 1.25, tracking: -0.02, isUppercase: true, color: .white, hasShadow: true, hasOutline: true)
        case .editorial:
            TextLook(font: .dmSerif, weight: .regular, sizeScale: 1.12, color: .white, hasShadow: true)
        case .bold:
            TextLook(font: .spaceGrotesk, weight: .bold, sizeScale: 1, tracking: 0.01, isUppercase: true, color: .white, hasShadow: true, hasOutline: true)
        case .pop:
            TextLook(font: .spaceGrotesk, weight: .bold, sizeScale: 1.05, color: .yellow, hasShadow: true, hasOutline: true)
        case .soft:
            TextLook(font: .dmSans, weight: .bold, sizeScale: 0.9, color: .offBlack, background: .pill, backgroundColor: .white, hasShadow: false)
        case .minimal:
            TextLook(font: .dmSans, weight: .medium, sizeScale: 0.85, tracking: 0.01, color: .white, hasShadow: true)
        case .label:
            TextLook(
                font: .spaceGrotesk, weight: .semibold, sizeScale: 0.62, tracking: 0.08, isUppercase: true, color: .white,
                background: .box, backgroundColor: .black, backgroundOpacity: 0.8, hasShadow: false
            )
        case .paper:
            TextLook(font: .dmSerif, weight: .regular, sizeScale: 1, color: .offBlack, background: .box, backgroundColor: .paper, hasShadow: false)
        }
    }

    /// Captions stay under 1.2× so a line of five words fits, and every one keeps a shadow, an
    /// outline or a fill to read over any background.
    private var captionLook: TextLook {
        switch self {
        case .impact:
            TextLook(font: .classic, weight: .heavy, sizeScale: 1.15, isUppercase: true, color: .white, hasShadow: true, hasOutline: true)
        case .label:
            // A tag's small capitals are too small for a line read in a second: a little bigger.
            TextLook(
                font: .spaceGrotesk, weight: .semibold, sizeScale: 0.9, tracking: 0.04, isUppercase: true, color: .white,
                background: .box, backgroundColor: .black, backgroundOpacity: 0.8, hasShadow: false
            )
        default:
            {
                var look = titleLook
                look.sizeScale = min(look.sizeScale, 1.1)
                look.verticalOffset = 0
                // A heavy title face is too dense for a line read word by word: one step lighter.
                if look.weight == .heavy { look.weight = .bold }
                return look
            }()
        }
    }
}
