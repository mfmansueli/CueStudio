//
//  BrandKit.swift
//  Cue Studio
//

import Foundation

/// A brand's look, saved once and put on any video ("Meu estilo", owner 08/11/2026): its colors, its fonts (for titles and for
/// captions), its logo, how the creator edits (`editing`: Clean up and sound), whether new videos open in it, and the
/// creator's own text, caption and cover styles (copies of them as they were saved here: changing or deleting the saved
/// style later doesn't change the kit, and changing the kit never changes a video already made). Every part is optional; a
/// creator who works with several brands keeps one kit each.
nonisolated struct BrandKit: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var colors: [OverlayColor] = []
    /// Texts' and the cover title's family.
    var titleFont: TextOverlayFont?
    var captionFont: TextOverlayFont?
    var logo: BrandKitLogo?
    var textStyle: BrandKitStyle<TextLook>?
    var captionStyle: BrandKitStyle<MyCaptionStyle>?
    var coverStyle: BrandKitStyle<CoverStyle>?
    /// How the creator cleans up a video and its sound (`BrandKitEditing`); nil when the kit keeps none.
    var editing: BrandKitEditing?
    /// The kit new videos open in (owner, 08/11/2026): at most one kit has it (`BrandKitStore.save`). Nil: no.
    var usesOnNewVideos: Bool?
    var createdAt = Date.now
    var updatedAt = Date.now

    /// The most colors a kit keeps: what fits on a row of the editor's palette.
    static let maximumColors = 6

    /// The parts it has.
    var parts: [BrandKitPart] {
        BrandKitPart.allCases.filter(has)
    }

    func has(_ part: BrandKitPart) -> Bool {
        switch part {
        case .colors: !colors.isEmpty
        case .fonts: titleFont != nil || captionFont != nil
        case .logo: logo != nil
        case .textStyle: textStyle != nil
        case .captionStyle: captionStyle != nil
        case .coverStyle: coverStyle != nil
        case .editing: editing != nil
        case .studioVoice: editing != nil
        case .zoom: editing?.zoom != nil
        }
    }

    /// Every imported family it names, for the font sweep.
    var fontFamilies: Set<String> {
        var fonts = [titleFont, captionFont, textStyle?.look.font, captionStyle?.look.settings.face].compactMap { $0?.customFamily }
        if let cover = coverStyle?.look.title.font.face.customFamily { fonts.append(cover) }
        return Set(fonts)
    }
}
