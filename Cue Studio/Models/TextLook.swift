//
//  TextLook.swift
//  Cue Studio
//

import Foundation

/// How a text reads on the video, apart from what it says and when: font, weight, size, letter
/// spacing, case, alignment, colors, fill, shadow, outline and height. Texts and captions share
/// it, so a preset or "My style" looks the same on both, and the preview and the export draw it
/// with the same renderer (`TextOverlayRenderer`).
///
/// Only the type: a look never touches the picture (filters, Adjust) or the cover.
nonisolated struct TextLook: Codable, Hashable, Sendable {
    /// Letter spacing as a fraction of the font size.
    static let trackingRange: ClosedRange<Double> = -0.05...0.25
    /// Size relative to the text's base size.
    static let sizeScaleRange: ClosedRange<Double> = 0.5...2.4
    /// Points on a 402-point-wide frame for a caption at scale 1.
    static let captionBaseSize: Double = 17

    var font: TextOverlayFont = .classic
    var weight: TextOverlayWeight = .bold
    /// Times the base size: a title's role (`TextOverlayRole.baseSize`), or `captionBaseSize`.
    var sizeScale: Double = 1
    var tracking: Double = 0
    var isUppercase = false
    var alignment: TextOverlayAlignment = .center
    var color: OverlayColor = .white
    var background: TextOverlayBackground = .none
    var backgroundColor: OverlayColor = .black
    /// 0 to 1: how solid the fill behind the words is.
    var backgroundOpacity: Double = 1
    var hasShadow = true
    var hasOutline = false
    /// 0 to 1: a soft light in the text's own color around the words (Text style › Glow). It stands in for the drop shadow.
    var glow: Double = 0
    /// Moves a title up (negative) or down from its role's usual height, as a fraction of the
    /// frame. Captions sit where their position (top, middle, bottom) puts them.
    var verticalOffset: Double = 0

    /// Sets `text`'s look, leaving alone what it says, when it shows and the fields in `kept`.
    func apply(to text: inout TextOverlay, keeping kept: Set<TextLookField> = []) {
        if !kept.contains(.font) { text.font = font }
        if !kept.contains(.weight) { text.weight = weight }
        if !kept.contains(.size) {
            text.size = min(max(text.role.baseSize * sizeScale, TextOverlay.sizeRange.lowerBound), TextOverlay.sizeRange.upperBound)
        }
        if !kept.contains(.tracking) { text.tracking = tracking }
        if !kept.contains(.letterCase) { text.isUppercase = isUppercase }
        if !kept.contains(.alignment) { text.alignment = alignment }
        if !kept.contains(.color) { text.color = color }
        if !kept.contains(.background) {
            text.background = background
            text.backgroundColor = backgroundColor
            text.backgroundOpacity = backgroundOpacity
        }
        if !kept.contains(.shadow) { text.hasShadow = hasShadow }
        if !kept.contains(.outline) { text.hasOutline = hasOutline }
        if !kept.contains(.glow) { text.glow = glow }
        if !kept.contains(.position) {
            text.center = OverlayPoint(x: 0.5, y: text.role.defaultY + verticalOffset).clamped
        }
    }

    /// The look `text` has now (how "My style" is saved from a text).
    init(of text: TextOverlay) {
        font = text.font
        weight = text.weight
        sizeScale = min(max(text.size / text.role.baseSize, Self.sizeScaleRange.lowerBound), Self.sizeScaleRange.upperBound)
        tracking = text.tracking
        isUppercase = text.isUppercase
        alignment = text.alignment
        color = text.color
        background = text.background
        backgroundColor = text.backgroundColor
        backgroundOpacity = text.backgroundOpacity
        hasShadow = text.hasShadow
        hasOutline = text.hasOutline
        glow = text.glow
        verticalOffset = text.center.y - text.role.defaultY
    }

    init(
        font: TextOverlayFont = .classic, weight: TextOverlayWeight = .bold, sizeScale: Double = 1, tracking: Double = 0,
        isUppercase: Bool = false, alignment: TextOverlayAlignment = .center, color: OverlayColor = .white,
        background: TextOverlayBackground = .none, backgroundColor: OverlayColor = .black, backgroundOpacity: Double = 1,
        hasShadow: Bool = true, hasOutline: Bool = false, glow: Double = 0, verticalOffset: Double = 0
    ) {
        self.font = font
        self.weight = weight
        self.sizeScale = sizeScale
        self.tracking = tracking
        self.isUppercase = isUppercase
        self.alignment = alignment
        self.color = color
        self.background = background
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.hasShadow = hasShadow
        self.hasOutline = hasOutline
        self.glow = glow
        self.verticalOffset = verticalOffset
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case font, weight, sizeScale, tracking, isUppercase, alignment, color, background, backgroundColor
        case backgroundOpacity, hasShadow, hasOutline, glow, verticalOffset
    }

    /// A field this version doesn't know, or a value out of range, falls back rather than failing.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = TextLook()
        font = (try? container.decodeIfPresent(TextOverlayFont.self, forKey: .font)) ?? defaults.font
        weight = (try? container.decodeIfPresent(TextOverlayWeight.self, forKey: .weight)) ?? defaults.weight
        let scale = (try? container.decodeIfPresent(Double.self, forKey: .sizeScale)) ?? defaults.sizeScale
        sizeScale = min(max(scale, Self.sizeScaleRange.lowerBound), Self.sizeScaleRange.upperBound)
        let spacing = (try? container.decodeIfPresent(Double.self, forKey: .tracking)) ?? defaults.tracking
        tracking = min(max(spacing, Self.trackingRange.lowerBound), Self.trackingRange.upperBound)
        isUppercase = (try? container.decodeIfPresent(Bool.self, forKey: .isUppercase)) ?? defaults.isUppercase
        alignment = (try? container.decodeIfPresent(TextOverlayAlignment.self, forKey: .alignment)) ?? defaults.alignment
        color = (try? container.decodeIfPresent(OverlayColor.self, forKey: .color)) ?? defaults.color
        background = (try? container.decodeIfPresent(TextOverlayBackground.self, forKey: .background)) ?? defaults.background
        backgroundColor = (try? container.decodeIfPresent(OverlayColor.self, forKey: .backgroundColor)) ?? defaults.backgroundColor
        let opacity = (try? container.decodeIfPresent(Double.self, forKey: .backgroundOpacity)) ?? defaults.backgroundOpacity
        backgroundOpacity = min(max(opacity, 0), 1)
        hasShadow = (try? container.decodeIfPresent(Bool.self, forKey: .hasShadow)) ?? defaults.hasShadow
        hasOutline = (try? container.decodeIfPresent(Bool.self, forKey: .hasOutline)) ?? defaults.hasOutline
        glow = min(max((try? container.decodeIfPresent(Double.self, forKey: .glow)) ?? defaults.glow, 0), 1)
        verticalOffset = (try? container.decodeIfPresent(Double.self, forKey: .verticalOffset)) ?? defaults.verticalOffset
    }
}
