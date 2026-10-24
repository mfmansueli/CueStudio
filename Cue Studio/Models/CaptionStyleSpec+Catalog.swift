//
//  CaptionStyleSpec+Catalog.swift
//  Cue Studio
//

import Foundation

/// The catalogue (version 3): twenty styles, each a whole recipe of type, contrast, background and motion, never only a
/// color away from another (`CaptionCatalogTests` checks that every two differ in at least two of family, case, background,
/// the word being said and the way in). Every one keeps its words readable on a white and on a black picture without moving:
/// a box, a thick outline or a dark halo is always behind the letters (`CaptionCatalogContrastTests`, measured on the drawn
/// pixels). The seven styles that existed before keep their earlier readings for the edits saved with them.
nonisolated extension CaptionStyleSpec {
    static func catalog(_ theme: CaptionTheme) -> CaptionStyleSpec {
        switch theme.category {
        case .cue: cueStyle(theme)
        case .essentials: essential(theme)
        case .impact: impactStyle(theme)
        case .editorial: editorialStyle(theme)
        case .colorful: colorful(theme)
        }
    }

    private static func cueStyle(_ theme: CaptionTheme) -> CaptionStyleSpec {
        switch theme {
        case .glide: glide
        case .spotlight: spotlight
        case .reveal: reveal
        default: signature
        }
    }

    private static func essential(_ theme: CaptionTheme) -> CaptionStyleSpec {
        switch theme {
        case .educational: darkBox
        case .outline: outline
        case .band: band
        default: clean
        }
    }

    private static func impactStyle(_ theme: CaptionTheme) -> CaptionStyleSpec {
        switch theme {
        case .bold: bold
        case .comic: comic
        case .punch: punch
        default: condensed
        }
    }

    private static func editorialStyle(_ theme: CaptionTheme) -> CaptionStyleSpec {
        switch theme {
        case .paper: paper
        case .interview: interview
        case .mono: mono
        default: serif
        }
    }

    private static func colorful(_ theme: CaptionTheme) -> CaptionStyleSpec {
        switch theme {
        case .lightPill: lightPill
        case .coral: coral
        case .cyanNight: cyanNight
        default: violet
        }
    }

    /// The recipe playing `motion`: what an earlier version would play instead is written beside it.
    private func playing(_ motion: CaptionMotion) -> CaptionStyleSpec {
        var spec = self
        spec.motion = motion
        spec.animation = motion.nearestAnimation
        spec.highlightsWithBox = motion.spoken.boxes
        spec.strokesOutside = true
        if spec.entry == .none { spec.entry = motion.entry.drawn }
        return spec
    }

    private static let ink = RGB(.offBlack)

    // MARK: - Cue

    /// The signature: Space Grotesk bold, the word being said on a yellow box, a dark halo so white words read on a white wall.
    private static var signature: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "SpaceGrotesk-Light", fontWeight: 700, fallbackWeight: 700, baseSize: 26, lineSpacing: 1,
            shadow: .halo, animation: .line, defaultAccent: .yellow, emphasisColor: .yellow
        ).playing(CaptionMotion(spoken: .box))
    }

    private static var glide: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Rubik", fontWeight: 800, face: .rubik, fallbackWeight: 800, baseSize: 25, uppercase: true, lineSpacing: 2,
            outline: Outline(width: 8, color: .black), shadow: Shadow(opacity: 0.5, blur: 3, offsetY: 1),
            animation: .line, defaultAccent: .lavender, emphasisColor: .yellow, spokenBoxRadius: 7
        ).playing(CaptionMotion(entry: .pop, spoken: .glide))
    }

    private static var spotlight: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "TikTokSans", fontWeight: 800, face: .tiktokSans, fallbackWeight: 800, baseSize: 26, lineSpacing: 1,
            outline: Outline(width: 6.5, color: .black), shadow: Shadow(opacity: 0.45, blur: 3, offsetY: 1),
            animation: .line, defaultAccent: .lime, emphasisColor: .yellow
        ).playing(CaptionMotion(spoken: .pop))
    }

    /// Words appear as they are said, each landing with a small pop in the words' own white.
    private static var reveal: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Poppins", fontWeight: 700, face: .poppins, fallbackWeight: 700, baseSize: 25, lineSpacing: 2,
            shadow: .halo, animation: .line, defaultAccent: .white, emphasisColor: .yellow
        ).playing(CaptionMotion(entry: .fade, reveal: .words, spoken: .pop))
    }

    // MARK: - Essentials

    private static var clean: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Inter-Regular", fontWeight: 600, fallbackWeight: 600, baseSize: 24, lineSpacing: 1,
            shadow: .halo, animation: .line, defaultAccent: .yellow, emphasisColor: .yellow
        ).playing(CaptionMotion(entry: .fade))
    }

    private static var darkBox: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Manrope-Regular", fontWeight: 700, fallbackWeight: 700, baseSize: 24, lineSpacing: 3,
            plate: .block(color: RGB(red: 0, green: 0, blue: 0, alpha: 0.75), radius: 8, insetX: 12, insetY: 5),
            widthFraction: 0.84, balanceFromWords: 5, balanceRatio: 1.6,
            animation: .line, defaultAccent: .yellow, emphasisColor: .lime
        ).playing(CaptionMotion(spoken: .color))
    }

    private static var outline: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Montserrat", fontWeight: 800, face: .montserrat, fallbackWeight: 800, baseSize: 25, lineSpacing: 1,
            outline: Outline(width: 7, color: .black), shadow: Shadow(opacity: 0.4, blur: 3, offsetY: 1),
            animation: .line, defaultAccent: .yellow, entry: Entry(fade: 0.06, popScale: 0.9, popDuration: 0.14), emphasisColor: .peach
        ).playing(CaptionMotion(entry: .pop, spoken: .color))
    }

    private static var band: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "DMSans", fontWeight: 700, face: .dmSans, fallbackWeight: 700, baseSize: 20, uppercase: true, tracking: 1.4,
            lineSpacing: 8, plate: .perLine(color: RGB(red: 0, green: 0, blue: 0, alpha: 0.86), radius: 0, insetX: 16, insetY: 4),
            widthFraction: 0.86, animation: .line, defaultAccent: .yellow, emphasisColor: .yellow
        ).playing(CaptionMotion(entry: .rise))
    }

    // MARK: - Impact

    private static var condensed: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Anton-Regular", fontWeight: 400, fallbackWeight: 700, baseSize: 30, uppercase: true, lineSpacing: 1,
            outline: Outline(width: 7, color: .black), shadow: Shadow(opacity: 0.55, blur: 4, offsetY: 2),
            widthFraction: 0.72, balanceFromWords: 3, balanceRatio: 1.5, maxLines: 2,
            animation: .line, defaultAccent: .lime, entry: Entry(popScale: 0.9, popDuration: 0.1), emphasisColor: .yellow
        ).playing(CaptionMotion(entry: .pop, spoken: .color))
    }

    private static var bold: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Montserrat", fontWeight: 800, face: .montserrat, fallbackWeight: 800, baseSize: 28, uppercase: true, lineSpacing: 0,
            outline: Outline(width: 7, color: .black), shadow: Shadow(opacity: 0.55, blur: 4, offsetY: 2),
            widthFraction: 0.76, balanceFromWords: 3, balanceRatio: 1.5, maxLines: 2,
            animation: .line, defaultAccent: .yellow, emphasisColor: .lime
        ).playing(CaptionMotion(entry: .rise, spoken: .pop))
    }

    private static var comic: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Bangers-Regular", fontWeight: 400, face: .bangers, fallbackWeight: 800, baseSize: 31, uppercase: true, tracking: 1,
            lineSpacing: 1, outline: Outline(width: 9, color: .black), shadow: Shadow(opacity: 0.7, blur: 0, offsetY: 3),
            widthFraction: 0.74, balanceFromWords: 3, balanceRatio: 1.5, maxLines: 2,
            animation: .line, defaultAccent: .mint, entry: Entry(fade: 0.04, popScale: 0.8, popDuration: 0.22),
            emphasisColor: .yellow, emphasisScale: 1.2
        ).playing(CaptionMotion(entry: .pop, spoken: .pop))
    }

    private static var punch: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Unbounded", fontWeight: 800, face: .unbounded, fallbackWeight: 800, baseSize: 23, uppercase: true, tracking: 0.6,
            lineSpacing: 3,
            outline: Outline(width: 9, color: .black), shadow: Shadow(opacity: 0.5, blur: 3, offsetY: 1),
            widthFraction: 0.72, balanceFromWords: 3, balanceRatio: 1.5, maxLines: 2, animation: .line, defaultAccent: .red,
            entry: Entry(fade: 0.04, popScale: 0.78, popDuration: 0.16),
            emphasisColor: .yellow, spokenBoxRadius: 12
        ).playing(CaptionMotion(entry: .pop, spoken: .box))
    }

    // MARK: - Editorial

    private static var serif: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "DMSerifDisplay-Regular", fontWeight: 400, fallbackWeight: 700, baseSize: 25, tracking: 0.6, lineSpacing: 4,
            textColor: RGB(red: 0.96, green: 0.96, blue: 0.96),
            plate: .block(color: RGB(red: 0, green: 0, blue: 0, alpha: 0.66), radius: 4, insetX: 14, insetY: 6),
            widthFraction: 0.78, animation: .line, defaultAccent: .peach, entry: Entry(fade: 0.2), emphasisColor: .yellow
        ).playing(CaptionMotion(entry: .fade, spoken: .color))
    }

    private static var paper: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "InstrumentSerif-Regular", fontWeight: 400, face: .instrumentSerif, fallbackWeight: 600, baseSize: 28, lineSpacing: 2,
            // A light paper: the red of the word said and the blue of a marked word both reach 3:1 on it (cream gave 2.97).
            textColor: ink, plate: .perLine(color: RGB(red: 0.99, green: 0.973, blue: 0.94), radius: 4, insetX: 12, insetY: 3),
            widthFraction: 0.8, animation: .line, defaultAccent: .red, emphasisColor: .blue
        ).playing(CaptionMotion(entry: .rise, spoken: .color))
    }

    private static var interview: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "DMSans", fontWeight: 500, face: .dmSans, fallbackWeight: 600, baseSize: 23, tracking: 0.2, lineSpacing: 2,
            plate: .block(color: RGB(red: 0, green: 0, blue: 0, alpha: 0.6), radius: 4, insetX: 9, insetY: 3),
            widthFraction: 0.78, balanceFromWords: 4, balanceRatio: 1.8, maxLines: 2,
            animation: .line, defaultAccent: .white, entry: Entry(fade: 0.1), emphasisColor: .yellow
        ).playing(CaptionMotion(entry: .fade))
    }

    private static var mono: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "SpaceMono-Bold", fontWeight: 700, face: .spaceMono, fallbackWeight: 700, baseSize: 20, lineSpacing: 3,
            textColor: RGB(.lime),
            plate: .block(color: RGB(red: 0.02, green: 0.02, blue: 0.02, alpha: 0.88), radius: 3, insetX: 12, insetY: 6),
            widthFraction: 0.84, animation: .line, defaultAccent: .white, emphasisColor: .white
        ).playing(CaptionMotion(reveal: .words))
    }

    // MARK: - Colorful

    private static var violet: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Poppins-ExtraBold", fontWeight: 800, fallbackWeight: 800, baseSize: 25, lineSpacing: 6,
            plate: .perLine(color: RGB(red: 0.39, green: 0.16, blue: 0.77), radius: 10, insetX: 11, insetY: 3),
            animation: .line, defaultAccent: .yellow, entry: Entry(popScale: 0.86, popDuration: 0.18), emphasisColor: .mint
        ).playing(CaptionMotion(entry: .pop, spoken: .color))
    }

    private static var lightPill: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Rubik", fontWeight: 700, face: .rubik, fallbackWeight: 700, baseSize: 24, lineSpacing: 6,
            textColor: ink, plate: .perLine(color: RGB(red: 1, green: 1, blue: 1, alpha: 0.96), radius: 999, insetX: 14, insetY: 4),
            animation: .line, defaultAccent: .blue, entry: Entry(fade: 0.06, popScale: 0.92, popDuration: 0.14), emphasisColor: .red
        ).playing(CaptionMotion(entry: .pop, spoken: .color))
    }

    /// Dark words on coral: the marked words stand out by size, the coral leaves no other color to read on it.
    private static var coral: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Syne", fontWeight: 800, face: .syne, fallbackWeight: 800, baseSize: 25, lineSpacing: 2,
            textColor: ink, plate: .block(color: RGB(red: 1, green: 0.5, blue: 0.42), radius: 12, insetX: 14, insetY: 6),
            animation: .line, defaultAccent: .offBlack, emphasisColor: .offBlack, emphasisScale: 1.3, spokenBoxRadius: 6
        ).playing(CaptionMotion(entry: .rise, spoken: .box))
    }

    private static var cyanNight: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "SpaceGrotesk-Light", fontWeight: 700, face: .spaceGrotesk, fallbackWeight: 700, baseSize: 22, uppercase: true,
            tracking: 0.8, lineSpacing: 3, textColor: RGB(.cyan),
            plate: .block(color: RGB(red: 0.03, green: 0.05, blue: 0.1, alpha: 0.9), radius: 6, insetX: 12, insetY: 5),
            animation: .line, defaultAccent: .white, emphasisColor: .yellow
        ).playing(CaptionMotion(entry: .rise, spoken: .color))
    }
}
