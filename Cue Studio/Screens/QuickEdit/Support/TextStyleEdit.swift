//
//  TextStyleEdit.swift
//  Cue Studio
//

import Foundation

/// One change made in Text style's Font or Color tab, applied the same way to a text and to the
/// captions' look (when "+ Captions" is the scope). Size only changes texts: captions keep theirs.
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
        case .backgroundColor(let color):
            text.backgroundColor = color
        case .shadow(let shadow):
            text.hasShadow = shadow.hasShadow
            text.hasOutline = shadow.hasOutline
        case .glow(let glow):
            text.glow = min(max(glow, 0), 1)
        }
    }
}
