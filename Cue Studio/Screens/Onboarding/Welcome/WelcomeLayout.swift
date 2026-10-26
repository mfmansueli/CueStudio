//
//  WelcomeLayout.swift
//  Cue Studio
//

import CoreGraphics

/// Where 1.1's parts go on a screen of any size. The board is 390 × 844: the star's C above, the wordmark, title and words from 350 pt
/// down, "Get started" 82 pt above the bottom edge. The words and the button keep their sizes (they are type) and the button stays where
/// the thumb finds it; the star's scene is drawn bigger or smaller (`artScale`) to fill what is left above the words: on an iPhone SE
/// (667 pt tall) the board's 844 pt left the button off the screen, on a Pro Max (956 pt) everything sat small at the top.
nonisolated struct WelcomeLayout: Equatable {
    /// The board's frame and where its words begin (the wordmark's top).
    static let board = CGSize(width: 390, height: 844)
    static let boardTextTop: CGFloat = 350
    static let buttonHeight: CGFloat = 54
    /// Between the last words and the button, as on the board.
    static let buttonGap: CGFloat = 26
    /// How far the star's scene may shrink or grow.
    static let artScales: ClosedRange<CGFloat> = 0.6...1.15

    let artScale: CGFloat
    /// The wordmark's top, from the top of the screen.
    let textTop: CGFloat
    /// The button's distance from the bottom edge.
    let buttonBottom: CGFloat

    /// `screen` is the whole screen; `textHeight` the wordmark, title and words as laid out (0 before they are).
    init(screen: CGSize, hasHomeIndicator: Bool, textHeight: CGFloat) {
        // 82 pt on the board counts the Home Indicator's strip; without one (SE) the button comes down to the same distance from the words.
        buttonBottom = hasHomeIndicator ? 82 : 48
        let buttonTop = screen.height - buttonBottom - Self.buttonHeight
        let lowestTextTop = buttonTop - Self.buttonGap - textHeight
        let fitting = min(lowestTextTop / Self.boardTextTop, screen.width / Self.board.width)
        artScale = min(max(fitting, Self.artScales.lowerBound), Self.artScales.upperBound)
        // What the scene leaves free goes half above the words and half below them.
        textTop = min(lowestTextTop, (Self.boardTextTop * artScale + lowestTextTop) / 2)
    }

    /// A point of the screen in the board's frame, where the star flies: the scene is centred and scaled from the top.
    func boardPoint(_ point: CGPoint, screenWidth: CGFloat) -> CGPoint {
        CGPoint(x: Self.board.width / 2 + (point.x - screenWidth / 2) / artScale, y: point.y / artScale)
    }
}
