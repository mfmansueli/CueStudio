//
//  FrameMaskCaptionTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// "16:9 · ONLY THE FRAME IS RECORDED" goes in the first free strip of the darkened camera: under the frame and the text window, above the
/// controls; else above both, under the top bar; never over the words or the controls.
@Suite("Frame mask caption")
struct FrameMaskCaptionTests {
    /// A 16:9 frame on an iPhone 17 (402 wide), its text window over it, the controls from 628.
    private let frame = CGRect(x: 0, y: 143, width: 402, height: 226)
    private let window = CGRect(x: 12, y: 60, width: 378, height: 192)

    @Test func itSitsUnderTheFrameAndTheWindowWhenThatStripIsFree() throws {
        let y = try #require(FrameMaskCaption.centerY(frame: frame, window: window, top: 106, bottom: 628))
        #expect(y == frame.maxY + FrameMaskCaption.gap + FrameMaskCaption.height / 2)
    }

    /// The owner's iPhone 15 Pro with a YouTube frame (09/11/2026): 18 pt between the frame's bottom and the controls is enough.
    @Test func theNarrowStripOverTheControlsIsEnough() throws {
        let youtube = CGRect(x: 0, y: 143, width: 393, height: 112)
        let words = CGRect(x: 12, y: 60, width: 369, height: 193)
        #expect(FrameMaskCaption.centerY(frame: youtube, window: words, top: 92, bottom: 273) != nil)
    }

    @Test func aLongWindowPushesItUnderTheWindow() throws {
        let tall = CGRect(x: 12, y: 60, width: 378, height: 420)
        let y = try #require(FrameMaskCaption.centerY(frame: frame, window: tall, top: 106, bottom: 628))
        #expect(y - FrameMaskCaption.height / 2 >= tall.maxY)
    }

    @Test func withNoRoomBelowItGoesAboveAndWithNoneAboveItIsLeftOut() throws {
        let low = CGRect(x: 0, y: 300, width: 402, height: 320)
        let above = try #require(FrameMaskCaption.centerY(frame: low, window: nil, top: 106, bottom: 628))
        #expect(above + FrameMaskCaption.height / 2 <= low.minY)
        let full = CGRect(x: 0, y: 110, width: 402, height: 515)
        #expect(FrameMaskCaption.centerY(frame: full, window: nil, top: 106, bottom: 628) == nil)
    }
}
