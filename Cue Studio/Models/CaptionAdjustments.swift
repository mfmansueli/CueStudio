//
//  CaptionAdjustments.swift
//  Cue Studio
//

import Foundation

/// What the creator changed over the caption style's own look (Caption style › Adjust): each field nil until changed, so
/// the style keeps everything else, "· N changed" counts what is set, and going back to the style's look clears it. The
/// same controls for every style: a preset, a saved style, or a text's look copied onto the captions. Picking another style
/// replaces them (they belong to the look, not to where the captions sit: `CaptionSettings`' size, place, width, alignment and
/// format stay).
nonisolated struct CaptionAdjustments: Codable, Hashable, Sendable {
    /// Letter spacing the creator can set, in points at the reference width.
    static let trackingRange: ClosedRange<Double> = 0...3

    var weight: TextOverlayWeight?
    var letterCase: CaptionLetterCase?
    var textColor: OverlayColor?
    var background: CaptionBackground?
    var backgroundColor: OverlayColor?
    /// 0.3 to 1: how solid the background is.
    var backgroundOpacity: Double?
    var outline: CaptionOutlineWeight?
    var outlineColor: OverlayColor?
    var shadow: CaptionShadowStyle?
    var tracking: Double?
    var emphasisColor: OverlayColor?
    var emphasisSize: CaptionEmphasisSize?

    init() {}

    /// How many of the look's parts are changed.
    var changedCount: Int {
        let changed: [Bool] = [
            weight != nil, letterCase != nil, textColor != nil, background != nil, backgroundColor != nil, backgroundOpacity != nil,
            outline != nil, outlineColor != nil, shadow != nil, tracking != nil, emphasisColor != nil, emphasisSize != nil,
        ]
        return changed.filter { $0 }.count
    }

    var isEmpty: Bool { changedCount == 0 }

    /// `spec` with these changes over it.
    func apply(to spec: inout CaptionStyleSpec) {
        if let weight { spec.fontWeight = weight.value }
        if let letterCase { spec.letterCase = letterCase }
        if let textColor { spec.textColor = CaptionStyleSpec.RGB(textColor) }
        if background != nil || backgroundColor != nil || backgroundOpacity != nil {
            let kind = background ?? CaptionBackground(spec.plate)
            let base = spec.plateColor ?? .black
            var color = backgroundColor.map(CaptionStyleSpec.RGB.init) ?? base
            color.alpha = backgroundOpacity.map { min(max($0, 0.3), 1) } ?? (spec.plateColor?.alpha ?? 0.72)
            spec.plate = kind.plate(color)
        }
        if let outline {
            spec.outline = outline.width.map { CaptionStyleSpec.Outline(width: $0, color: spec.outline?.color ?? .black) }
        }
        if let outlineColor, spec.outline != nil { spec.outline?.color = CaptionStyleSpec.RGB(outlineColor) }
        if let shadow { spec.shadow = shadow.shadow(textColor: spec.textColor) }
        if let tracking { spec.tracking = min(max(tracking, Self.trackingRange.lowerBound), Self.trackingRange.upperBound) }
        if let emphasisColor { spec.emphasisColor = emphasisColor }
        if let emphasisSize { spec.emphasisScale = emphasisSize.scale }
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case weight, letterCase, textColor, background, backgroundColor, backgroundOpacity, outline, outlineColor, shadow, tracking
        case emphasisColor, emphasisSize
    }

    /// A part this version doesn't know, or a number out of range, reads as unchanged rather than failing the captions.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weight = try? container.decodeIfPresent(TextOverlayWeight.self, forKey: .weight)
        letterCase = try? container.decodeIfPresent(CaptionLetterCase.self, forKey: .letterCase)
        textColor = try? container.decodeIfPresent(OverlayColor.self, forKey: .textColor)
        background = try? container.decodeIfPresent(CaptionBackground.self, forKey: .background)
        backgroundColor = try? container.decodeIfPresent(OverlayColor.self, forKey: .backgroundColor)
        backgroundOpacity = (try? container.decodeIfPresent(Double.self, forKey: .backgroundOpacity)).flatMap { $0.map { min(max($0, 0.3), 1) } }
        outline = try? container.decodeIfPresent(CaptionOutlineWeight.self, forKey: .outline)
        outlineColor = try? container.decodeIfPresent(OverlayColor.self, forKey: .outlineColor)
        shadow = try? container.decodeIfPresent(CaptionShadowStyle.self, forKey: .shadow)
        tracking = (try? container.decodeIfPresent(Double.self, forKey: .tracking)).flatMap { $0.map { min(max($0, 0), 3) } }
        emphasisColor = try? container.decodeIfPresent(OverlayColor.self, forKey: .emphasisColor)
        emphasisSize = try? container.decodeIfPresent(CaptionEmphasisSize.self, forKey: .emphasisSize)
    }
}
