//
//  TextStyleEdit.swift
//  Cue Studio
//

import Foundation

/// One change made in Text style's Presets, Font or Color tab, applied the same way to a text and to the
/// captions' look (when "+ Captions" is the scope). Size only changes texts: captions keep theirs. An effect's
/// settings change only a text that wears an effect, and only what its kind has (a direction it offers); its motion set to
/// Animated takes a Motion off the text, so the effect moves as its card shows.
nonisolated enum TextStyleEdit: Equatable, Sendable {
    case font(TextOverlayFont)
    case weight(TextOverlayWeight)
    /// Points on the design's frame (12 to 56).
    case size(Double)
    case color(OverlayColor)
    case background(TextOverlayBackground)
    case backgroundColor(OverlayColor)
    case shadow(TextShadowStyle)
    /// 0 to 1 (Text style › Glow).
    case glow(Double)
    /// The effect's second color (Pop 3D's depth, Headline's band).
    case effectAccent(OverlayColor)
    /// The Gold effect's metal.
    case effectTone(MetalTone)
    /// 0 to 1: the effect's own strength.
    case effectIntensity(Double)
    case effectMotion(TextEffectMotion)
    /// Seconds the effect's way in takes.
    case effectDuration(TimeInterval)
    case effectDirection(TextEffectDirection)
    /// The effect taken off; the type stays as it is.
    case removeEffect

    /// Sizes Text style can set, in the points of `TextOverlay.size` (the slider shows 24–120).
    static let sizeRange: ClosedRange<Double> = TextOverlay.sizeRange

    /// What it is remembered as when changed by hand on one text.
    var field: TextLookField {
        switch self {
        case .font: .font
        case .weight: .weight
        case .size: .size
        case .color: .color
        case .background, .backgroundColor: .background
        case .shadow: .shadow
        case .glow: .glow
        case .effectAccent, .effectTone, .effectIntensity, .effectMotion, .effectDuration, .effectDirection, .removeEffect: .effect
        }
    }

    func apply(to text: inout TextOverlay) {
        switch self {
        case .font(let font):
            text.font = font
            if !font.weights.contains(text.weight) { text.weight = font.weights[0] }
        case .weight(let weight):
            if text.font.weights.contains(weight) { text.weight = weight }
        case .size(let points):
            let clamped = min(max(points, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
            text.size = clamped
        case .color(let color):
            text.color = color
        case .background(let background):
            text.background = background
            if background != .none, text.backgroundOpacity < 0.05 { text.backgroundOpacity = 1 }
            // A fill always shows one of the palette's colors picked (an older text's black is Ink).
            if background != .none, text.backgroundColor == .black { text.backgroundColor = .offBlack }
        case .backgroundColor(let color):
            text.backgroundColor = color
        case .shadow(let shadow):
            text.hasShadow = shadow.hasShadow
            text.hasOutline = shadow.hasOutline
        case .glow(let glow):
            text.glow = min(max(glow, 0), 1)
        case .removeEffect:
            text.effect = nil
            // An effect's style without its effect is no longer that style.
            if text.preset?.effect != nil { text.preset = nil }
        default:
            applyEffect(to: &text)
        }
    }

    /// An effect's setting, on a text that wears one. Its motion set to Animated: it moves as its card shows, so a Motion
    /// (which would play instead) goes.
    private func applyEffect(to text: inout TextOverlay) {
        guard var effect = text.effect else { return }
        applyEffect(to: &effect)
        text.effect = effect
        if self == .effectMotion(.animated) { text.animation = nil }
    }

    private func applyEffect(to effect: inout TextEffect) {
        switch self {
        case .effectAccent(let color): effect.accent = color
        case .effectTone(let tone): effect.tone = tone
        case .effectIntensity(let intensity):
            effect.intensity = min(max(intensity, TextEffect.intensityRange.lowerBound), TextEffect.intensityRange.upperBound)
        case .effectMotion(let motion): effect.motion = motion
        case .effectDuration(let duration):
            effect.duration = min(max(duration, TextEffectKind.durationRange.lowerBound), TextEffectKind.durationRange.upperBound)
        case .effectDirection(let direction):
            if effect.kind.directions.contains(direction) { effect.direction = direction }
        default: break
        }
    }
}
