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
        "SpaceGrotesk-Variable",
        "Anton-Regular",
        "Inter-Variable",
        "Poppins-ExtraBold",
        "Manrope-Variable",
        "DMSans-Variable",
        "DMSerifDisplay-Regular",
        "Unbounded-Variable",
        "InstrumentSerif-Italic",
        "SpaceMono-Bold",
        "Syne-Variable",
        "Caveat-Variable",
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

    /// SF Pro, at a fixed size (the prompter's own slider sets it).
    static func system(size: CGFloat) -> Font {
        .system(size: size)
    }

    /// New York, the system's serif.
    static func newYork(size: CGFloat) -> Font {
        .system(size: size, design: .serif)
    }

    static func rounded(size: CGFloat) -> Font {
        .system(size: size, design: .rounded)
    }

    /// A family's chip in Text style and Caption style, drawn in that family (the only place the
    /// interface shows the fonts made for the video).
    static func chip(_ face: TextOverlayFont) -> Font {
        Font(TextFont.font(face, weight: face == .dmSerif ? .regular : .semibold, size: 15, text: face.label))
    }

    /// HUD signals (counters, time, status lines): small, monospaced, in capitals where the caller
    /// asks for it (`HUDLine`, `StageBar`). Scales with Dynamic Type.
    static let hud = Font.system(.caption, design: .monospaced, weight: .semibold)

    /// Countdown numerals over the camera.
    static let countdown = Font.system(size: 190, weight: .bold).monospacedDigit()
}
