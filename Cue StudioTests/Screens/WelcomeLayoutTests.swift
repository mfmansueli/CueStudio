//
//  WelcomeLayoutTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// 1.1 on every iPhone: as the board on a board-sized screen, the button on the screen and clear of the words on an SE, the scene
/// grown on a Pro Max.
struct WelcomeLayoutTests {
    private let boardText: CGFloat = 332

    @Test func onTheBoardsScreenItIsTheBoard() {
        let layout = WelcomeLayout(screen: CGSize(width: 390, height: 844), hasHomeIndicator: true, textHeight: boardText)
        #expect(layout.artScale == 1)
        #expect(layout.textTop == 350)
        #expect(layout.buttonBottom == 82)
    }

    @Test func onAnSETheWordsEndAboveTheButtonAndTheButtonIsOnTheScreen() {
        let screen = CGSize(width: 375, height: 667)
        let layout = WelcomeLayout(screen: screen, hasHomeIndicator: false, textHeight: 320)
        let buttonTop = screen.height - layout.buttonBottom - WelcomeLayout.buttonHeight
        #expect(buttonTop > 0 && layout.buttonBottom < 82)
        #expect(layout.textTop + 320 <= buttonTop - WelcomeLayout.buttonGap + 0.5)
        #expect(layout.artScale < 1, "The star's scene is drawn smaller to make room")
    }

    @Test func onAProMaxTheSceneGrowsWithTheWidth() {
        let layout = WelcomeLayout(screen: CGSize(width: 440, height: 956), hasHomeIndicator: true, textHeight: 350)
        #expect(layout.artScale > 1.1 && layout.artScale <= WelcomeLayout.artScales.upperBound)
        #expect(layout.textTop >= WelcomeLayout.boardTextTop * layout.artScale, "The words start below the scene")
    }

    @Test func thePillsCentresMapBackToTheBoard() {
        let layout = WelcomeLayout(screen: CGSize(width: 440, height: 956), hasHomeIndicator: true, textHeight: 350)
        let centre = layout.boardPoint(CGPoint(x: 220, y: 100 * layout.artScale), screenWidth: 440)
        #expect(abs(centre.x - 195) < 0.001)
        #expect(abs(centre.y - 100) < 0.001)
    }
}
