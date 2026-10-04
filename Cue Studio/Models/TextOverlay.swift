//
//  TextOverlay.swift
//  Cue Studio
//

import Foundation

/// A text laid over the edited video (a title, a hook, a callout…). Pinned to the recording like
/// captions: it shows while the part of the take it was placed on plays, so cutting or speeding
/// up something before it never moves it off what is being said. Rendered by the same code in the
/// preview and the export (`TextOverlayRenderer`).
nonisolated struct TextOverlay: Codable, Hashable, Identifiable, Sendable {
    static let sizeRange: ClosedRange<Double> = 12...120
    /// Shortest a text can stay on screen.
    static let minimumDuration: TimeInterval = 0.3

    var id = UUID()
    var text: String
    var role: TextOverlayRole
    var font: TextOverlayFont = .classic
    var weight: TextOverlayWeight = .bold
    /// Points on a 402-point-wide frame; scaled to the real frame when drawn.
    var size: Double
    /// Letter spacing as a fraction of the size (`TextLook.trackingRange`).
    var tracking: Double = 0
    var isUppercase = false
    var alignment: TextOverlayAlignment = .center
    var color: OverlayColor = .white
    var background: TextOverlayBackground = .none
    var backgroundColor: OverlayColor = .black
    /// 0 to 1: how solid the fill is.
    var backgroundOpacity: Double = 1
    var hasShadow = true
    var hasOutline = false
    /// 0 to 1: a soft light in the text's color around it (`TextLook.glow`).
    var glow: Double = 0
    /// The center of the text on the frame.
    var center: OverlayPoint
    /// Seconds of the recording it is pinned to.
    var span: TimeSpan
    /// In an arranged edit, the piece it is pinned to (`span` is then of that piece's recording);
    /// nil pins it to the take's own seconds.
    var clipAnchor: ClipAnchor?
    /// Where it goes, how big and how opaque over its own time; none stands still at `center`.
    var keyframes: [OverlayKeyframe] = []
    /// The preset it was last set in; nil for a look set another way (a legacy style, "My
    /// style").
    var preset: TypePreset?
    /// What the creator changed by hand since, kept when a preset is applied to every text with
    /// "Keep my changes".
    var customized: Set<TextLookField> = []

    /// A new text for `role` in `style` (edits made before type presets), shown over `span` of the
    /// recording.
    init(role: TextOverlayRole, style: CreatorStyle, span: TimeSpan) {
        text = role.placeholder
        self.role = role
        size = role.baseSize
        center = OverlayPoint(x: 0.5, y: role.defaultY)
        self.span = span
        style.apply(to: &self)
    }

    /// A new text for `role` with `look`, shown over `span` of the recording.
    init(role: TextOverlayRole, look: TextLook, preset: TypePreset?, span: TimeSpan) {
        text = role.placeholder
        self.role = role
        size = role.baseSize
        center = OverlayPoint(x: 0.5, y: role.defaultY)
        self.span = span
        self.preset = preset
        look.apply(to: &self)
    }

    /// A caption line drawn with `look` at `position`: captions and texts go through the same
    /// renderer, so a preset looks the same on both.
    /// `offset` moves it from its position (a fraction of the frame, down when positive): where a
    /// translation shows next to the original.
    static func caption(_ line: String, look: TextLook, position: CaptionPosition, span: TimeSpan, offset: Double = 0) -> TextOverlay {
        var overlay = TextOverlay(role: .subtitle, look: look, preset: nil, span: span)
        overlay.text = line
        overlay.size = min(max(TextLook.captionBaseSize * look.sizeScale, sizeRange.lowerBound), sizeRange.upperBound)
        overlay.center = OverlayPoint(x: 0.5, y: position.verticalFraction + offset)
        return overlay
    }

    /// What is drawn: the text, in capitals when the style asks for them.
    var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return isUppercase ? trimmed.uppercased() : trimmed
    }

    /// Nothing to draw.
    var isEmpty: Bool { displayText.isEmpty }

    /// The look it has now.
    var look: TextLook { TextLook(of: self) }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case id, text, role, font, weight, size, tracking, isUppercase, alignment, color, background, backgroundColor
        case backgroundOpacity, hasShadow, hasOutline, glow, center, span, preset, customized, clipAnchor, keyframes
    }

    /// Texts saved before letter spacing, fill opacity and presets read with none of them.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        role = try container.decode(TextOverlayRole.self, forKey: .role)
        font = try container.decodeIfPresent(TextOverlayFont.self, forKey: .font) ?? .classic
        weight = try container.decodeIfPresent(TextOverlayWeight.self, forKey: .weight) ?? .bold
        size = try container.decode(Double.self, forKey: .size)
        tracking = (try? container.decodeIfPresent(Double.self, forKey: .tracking)) ?? 0
        isUppercase = try container.decodeIfPresent(Bool.self, forKey: .isUppercase) ?? false
        alignment = try container.decodeIfPresent(TextOverlayAlignment.self, forKey: .alignment) ?? .center
        color = try container.decodeIfPresent(OverlayColor.self, forKey: .color) ?? .white
        background = try container.decodeIfPresent(TextOverlayBackground.self, forKey: .background) ?? .none
        backgroundColor = try container.decodeIfPresent(OverlayColor.self, forKey: .backgroundColor) ?? .black
        backgroundOpacity = min(max((try? container.decodeIfPresent(Double.self, forKey: .backgroundOpacity)) ?? 1, 0), 1)
        hasShadow = try container.decodeIfPresent(Bool.self, forKey: .hasShadow) ?? true
        hasOutline = try container.decodeIfPresent(Bool.self, forKey: .hasOutline) ?? false
        glow = min(max((try? container.decodeIfPresent(Double.self, forKey: .glow)) ?? 0, 0), 1)
        center = try container.decode(OverlayPoint.self, forKey: .center)
        span = try container.decode(TimeSpan.self, forKey: .span)
        preset = try? container.decodeIfPresent(TypePreset.self, forKey: .preset)
        customized = Set(((try? container.decodeIfPresent([String].self, forKey: .customized)) ?? []).compactMap(TextLookField.init(rawValue:)))
        clipAnchor = try? container.decodeIfPresent(ClipAnchor.self, forKey: .clipAnchor)
        keyframes = (try? container.decodeIfPresent([OverlayKeyframe].self, forKey: .keyframes)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(role, forKey: .role)
        try container.encode(font, forKey: .font)
        try container.encode(weight, forKey: .weight)
        try container.encode(size, forKey: .size)
        try container.encode(tracking, forKey: .tracking)
        try container.encode(isUppercase, forKey: .isUppercase)
        try container.encode(alignment, forKey: .alignment)
        try container.encode(color, forKey: .color)
        try container.encode(background, forKey: .background)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(backgroundOpacity, forKey: .backgroundOpacity)
        try container.encode(hasShadow, forKey: .hasShadow)
        try container.encode(hasOutline, forKey: .hasOutline)
        // Absent when none, so an edit made without glow encodes as it always did.
        if glow > 0 { try container.encode(glow, forKey: .glow) }
        try container.encode(center, forKey: .center)
        try container.encode(span, forKey: .span)
        try container.encodeIfPresent(preset, forKey: .preset)
        // Sorted, so the same text always encodes the same (drafts compare by value).
        try container.encode(customized.map(\.rawValue).sorted(), forKey: .customized)
        try container.encodeIfPresent(clipAnchor, forKey: .clipAnchor)
        if !keyframes.isEmpty { try container.encode(keyframes, forKey: .keyframes) }
    }
}
