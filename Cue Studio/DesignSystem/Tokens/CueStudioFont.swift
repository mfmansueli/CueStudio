//
//  CueStudioFont.swift
//  Cue Studio
//

import CoreText
import SwiftUI

/// Bundled typefaces (OFL, see Fonts/), registered once for prompter and video renderers.
/// Prompter helpers retain their original fonts; their own slider controls the fixed sizes.
enum CueStudioFont {
    private static let bundledFiles = [
        "Lexend-Variable",
        "AtkinsonHyperlegible-Regular",
        "AtkinsonHyperlegible-Bold",
        "SourceSerif4-Variable",
        "SpaceGrotesk-Variable",
        "Anton-Regular",
        "Inter-Variable",
        "Poppins-ExtraBold",
        "Manrope-Variable",
        "DMSans-Variable",
        "DMSerifDisplay-Regular",
    ]

    /// Registers the bundled fonts for this process. Call once at launch.
    static func registerFonts() {
        let urls = bundledFiles.compactMap { Bundle.main.url(forResource: $0, withExtension: "ttf") }
        guard !urls.isEmpty else { return }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }

    static func lexend(size: CGFloat) -> Font {
        .custom("Lexend-Regular", fixedSize: size)
    }

    static func legible(size: CGFloat) -> Font {
        .custom("AtkinsonHyperlegible-Regular", fixedSize: size)
    }

    static func serif(size: CGFloat) -> Font {
        .custom("SourceSerif4Roman-Regular", fixedSize: size)
    }

    static func rounded(size: CGFloat) -> Font {
        .system(size: size, design: .rounded)
    }

    /// A family's chip in Text style and Caption style, drawn in that family (the only place the
    /// interface shows the fonts made for the video).
    static func chip(_ face: TextOverlayFont) -> Font {
        Font(TextFont.font(face, weight: face == .dmSerif ? .regular : .semibold, size: 15, text: face.label))
    }

    /// Countdown numerals over the camera.
    static let countdown = Font.system(size: 190, weight: .bold).monospacedDigit()
}
