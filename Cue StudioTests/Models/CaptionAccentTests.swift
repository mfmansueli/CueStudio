//
//  CaptionAccentTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// A lit word's color stands out on captions in a text's look: not the text's color, not the fill
/// behind it; otherwise the next that does.
@Suite("Caption accent")
struct CaptionAccentTests {
    private func look(_ color: OverlayColor, background: TextOverlayBackground = .none, fill: OverlayColor = .black, opacity: Double = 1) -> TextLook {
        TextLook(color: color, background: background, backgroundColor: fill, backgroundOpacity: opacity)
    }

    @Test func aColorStandsOutUnlessItIsTheTextsOwn() {
        #expect(CaptionAccent.yellow.standsOut(on: look(.white)))
        #expect(!CaptionAccent.yellow.standsOut(on: look(.yellow)))
        #expect(!CaptionAccent.white.standsOut(on: look(.white)))
        #expect(!CaptionAccent.white.standsOut(on: look(.paper)))
        #expect(!CaptionAccent.peach.standsOut(on: look(.blush)))
        #expect(CaptionAccent.lime.standsOut(on: look(.mint)))
    }

    @Test func theFillBehindTheWordsCountsWhenItShows() {
        #expect(!CaptionAccent.yellow.standsOut(on: look(.offBlack, background: .pill, fill: .yellow)))
        // A fill that barely shows doesn't hide anything.
        #expect(CaptionAccent.yellow.standsOut(on: look(.offBlack, background: .pill, fill: .yellow, opacity: 0.1)))
    }

    @Test func theNextColorIsTheFirstThatStandsOut() {
        #expect(CaptionAccent.yellow.standingOut(on: look(.white)) == .yellow)
        #expect(CaptionAccent.yellow.standingOut(on: look(.yellow)) == .white)
        #expect(CaptionAccent.white.standingOut(on: look(.white)) == .yellow)
        // Yellow text on a white pill: neither yellow nor white, lime is next.
        #expect(CaptionAccent.yellow.standingOut(on: look(.yellow, background: .pill, fill: .white)) == .lime)
    }
}
