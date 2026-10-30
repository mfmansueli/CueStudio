//
//  CaptionSettings.swift
//  Cue Studio
//

import Foundation

/// How a video's captions look and where they sit. Two halves that a change of style treats apart: the **look** (the style,
/// `theme` read by `styleVersion`; what the creator changed over it, `face`, `accent`, `adjustments`; and how it moves,
/// `motion`), which another style replaces; and the **layout** (`sizeScale`, `center`, `width`, `alignment`, `format`), which
/// stays when the style changes. Local visual changes never request another transcription. Nil in TakeEdit means legacy.
nonisolated struct CaptionSettings: Codable, Hashable, Sendable {
    static let sizeRange: ClosedRange<Double> = 0.65...1.65

    var theme: CaptionTheme = .cue
    var sizeScale: Double = 1
    var center: OverlayPoint?
    var accent: CaptionAccent?
    var followsWords = true
    /// Captured from the project's platform, independent of later rules updates.
    var safeMargins = SafeZoneMargins()
    /// Which reading of the preset draws (`CaptionStyleSpec`): nil in settings saved before the
    /// complete presets, which keep the look they were made with.
    var styleVersion: Int?
    /// A text's look copied onto the captions by a version before Adjust: the lines are drawn in its font, colors, fill,
    /// shadow and glow instead of the preset's, as they were. The first change in Adjust turns it into `adjustments` over the
    /// style (`withoutCopiedLook`); copies made since are `adjustments` too. Settings saved before it read as nil.
    var customLook: TextLook?
    /// A family picked over the preset (Caption style › Adjust): the lines are drawn in it at the weight nearest the
    /// preset's, and everything else stays the preset's. Nil draws the preset's own font; picking a preset clears it.
    var face: TextOverlayFont?
    /// How the lines are cut into what shows at once (`CaptionFormat`, `CaptionBlocking`); the renderer keeps a block to the
    /// format's lines. Nil: the lines as they were made, drawn as before formats (edits saved before them read as nil).
    var format: CaptionFormat?
    /// What the creator changed over the style's look (Caption style › Adjust); nil: the style's own.
    var adjustments: CaptionAdjustments?
    /// How the captions move (Caption style › Animation); nil in edits saved before it, which play `TakeEdit.captionAnimation`
    /// the way they always did.
    var motion: CaptionMotion?
    /// How wide a line may run and how its lines align (Caption style › Format); nil: the style's own.
    var width: CaptionWidth?
    var alignment: LineAlignment?
    /// The saved style these captions were put in (`SavedStyle`), to name it on the card. Only a name: the look is this
    /// video's own copy, so changing or deleting the saved style never touches it.
    var savedStyleID: UUID?

    init(theme: CaptionTheme = .cue) {
        self.theme = theme
        styleVersion = CaptionStyleSpec.currentVersion
        let spec = CaptionStyleSpec.spec(for: theme, version: CaptionStyleSpec.currentVersion)
        motion = spec.motion
        followsWords = spec.motion?.followsWords ?? spec.animation.followsWords
    }

    /// The style's own recipe, before what the creator changed over it.
    var styleSpec: CaptionStyleSpec {
        CaptionStyleSpec.spec(for: theme, version: ReadingVersion.captionStyle.read(styleVersion))
    }

    /// The recipe the captions are drawn with: the style's, with the family, the changes and the layout picked over it.
    var spec: CaptionStyleSpec {
        var spec = styleSpec
        if let face { spec.face = face }
        adjustments?.apply(to: &spec)
        if let width { spec.widthFraction = width.fraction }
        if let alignment { spec.alignment = alignment }
        // A word that pops needs room on its line: the spaces leave it, in the layout and in the measure lines are cut by.
        if motion?.spoken == .pop { spec.wordSpacing = Self.popWordSpacing }
        return spec
    }

    /// The room a popping word's line leaves in each space, as a share of the type size.
    static let popWordSpacing = 0.22

    var highlightColor: CaptionAccent { accent ?? spec.defaultAccent }
    var clampedScale: Double {
        min(max(sizeScale.isFinite ? sizeScale : 1, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
    }

    /// How many parts of the look the creator changed over the style (the family, the highlight color and Adjust's).
    var changedLookCount: Int {
        (face == nil ? 0 : 1) + (adjustments?.changedCount ?? 0)
    }

    /// The same captions shown whole, never word by word (a translation's words aren't timed to the voice): they still come
    /// in and go out their way.
    var shownWhole: CaptionSettings {
        var whole = self
        whole.followsWords = false
        whole.motion?.reveal = .line
        whole.motion?.spoken = .none
        return whole
    }

    /// The weights Adjust offers: the family's (the one picked over the style, or the style's own).
    var availableWeights: [TextOverlayWeight] { spec.availableWeights }

    /// A look an earlier version copied from a text (`customLook`) as changes over the style, so every control works on it
    /// and the collection draws it: the family, weight, case, colors, fill, outline, shadow or glow, spacing and alignment.
    var withoutCopiedLook: CaptionSettings {
        guard let look = customLook else { return self }
        var next = self
        next.customLook = nil
        next.face = look.font
        var changes = adjustments ?? CaptionAdjustments()
        changes.weight = look.weight
        changes.letterCase = look.isUppercase ? .upper : .asTyped
        changes.textColor = look.color
        switch look.background {
        case .none: changes.background = CaptionBackground.none
        case .box: changes.background = .box
        case .pill: changes.background = .pill
        }
        changes.backgroundColor = look.backgroundColor
        changes.backgroundOpacity = look.backgroundOpacity
        changes.outline = look.hasOutline ? .thin : CaptionOutlineWeight.none
        changes.shadow = look.glow > 0.001 ? .glow : look.hasShadow ? .soft : CaptionShadowStyle.none
        // A text's spacing is a share of its size; the collection's is points at the reference width.
        changes.tracking = min(max(look.tracking * styleSpec.baseSize, CaptionAdjustments.trackingRange.lowerBound),
                               CaptionAdjustments.trackingRange.upperBound)
        next.adjustments = changes
        if look.alignment != .center { next.alignment = look.alignment }
        return next
    }

    // MARK: - Switching styles

    /// These captions in `theme`'s look and motion, keeping where they sit, how big, how wide, how aligned and how they are cut:
    /// another style changes the look, never the layout the creator set. `full` takes the style's own layout too.
    func restyled(_ theme: CaptionTheme, full: Bool = false) -> CaptionSettings {
        var next = CaptionSettings(theme: theme)
        next.safeMargins = safeMargins
        next.format = format
        guard !full else { return next }
        next.sizeScale = sizeScale
        next.center = center
        next.width = width
        next.alignment = alignment
        return next
    }

    /// The layout of `other` (size, place, width, alignment, format) on this look.
    func laidOut(like other: CaptionSettings) -> CaptionSettings {
        var next = self
        next.sizeScale = other.sizeScale
        next.center = other.center
        next.width = other.width
        next.alignment = other.alignment
        next.format = other.format ?? format
        return next
    }

    /// Whether the two place their captions alike (size, place, width, alignment).
    func sitsLike(_ other: CaptionSettings) -> Bool {
        clampedScale == other.clampedScale && center == other.center && width == other.width && alignment == other.alignment
    }

    /// The look alone (style, reading, family, highlight color, changes, motion, copied look), without the layout and the
    /// platform's margins: what two captions share when they look alike.
    var look: CaptionSettings {
        var look = CaptionSettings()
        look.theme = theme
        look.styleVersion = styleVersion
        look.accent = accent
        look.face = face
        look.customLook = customLook
        look.adjustments = adjustments?.isEmpty == true ? nil : adjustments
        look.motion = motion
        look.followsWords = followsWords
        return look
    }
}
