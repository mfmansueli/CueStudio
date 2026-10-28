//
//  TextEffectRequest.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Everything a text effect is drawn from, in the drawing's pixels: the words with their font, letter spacing and paragraph
/// (Core Text attributes), the effect as the creator tuned it, its colors, the letters' size, the widest a line can be and the
/// box's padding. Built by `TextOverlayRenderer` from a text, so the preview, the export and the panel's cards ask for the
/// same drawing.
nonisolated struct TextEffectRequest: @unchecked Sendable {
    let string: NSAttributedString
    let effect: TextEffect
    /// The words' color (the tube's tint for Neon); Gold paints with its metal instead.
    let color: TextEffectInk
    /// The depth's color (Pop 3D) or the band's (Headline).
    let accent: TextEffectInk
    /// The letters' size, in pixels.
    let pointSize: CGFloat
    /// The widest a line can be, in pixels.
    let maxWidth: CGFloat
    /// Between the box's edge and the lines, in pixels.
    let padding: CGSize
    /// Cut into words instead of letters: where letters join or stack (Arabic, the Indic scripts, Thai), for an effect that
    /// reads by word, and for a long text.
    let byWords: Bool
    /// Names the drawing in the cache: everything above, so a changed word, color or size is drawn again.
    let key: String

    /// The pixels the effect draws past the box on every side: its halo, depth, shadow, sparkles and travel.
    var room: CGFloat {
        let size = pointSize
        let strength = effect.intensity
        let reach: CGFloat = switch effect.kind {
        case .gold: 0.42
        case .wave: 0.2 + 0.75 * strength
        case .pop3D: 0.32 + 0.2 * strength
        case .neon: 0.55 + 0.6 * strength
        case .headline: 0.22
        case .sheen: 0.3
        }
        // Letters spread out as Sheen comes in: as far as a long line's ends travel.
        let spread = effect.kind == .sheen ? maxWidth * 0.06 : 0
        return ceil(size * reach + spread)
    }
}
