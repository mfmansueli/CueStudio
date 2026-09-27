//
//  CueStudioFont.swift
//  Cue Studio
//

import CoreText
import SwiftUI

/// Prompter typefaces. Lexend and Atkinson Hyperlegible are bundled (OFL, see Fonts/); serif and
/// rounded use the system designs. Sizes are fixed because the prompter has its own size slider.
enum CueStudioFont {
    private static let bundledFiles = [
        "Lexend-Variable",
        "AtkinsonHyperlegible-Regular",
        "AtkinsonHyperlegible-Bold",
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
        .system(size: size, design: .serif)
    }

    static func rounded(size: CGFloat) -> Font {
        .system(size: size, design: .rounded)
    }

    /// Countdown numerals over the camera.
    static let countdown = Font.system(size: 190, weight: .bold).monospacedDigit()
}
