//
//  ShareNetworkLineTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The mono line under each network of "Share to universe".
@Suite("ShareNetworkLine")
struct ShareNetworkLineTests {
    private let ideal: ClosedRange<TimeInterval> = 30...60

    @Test func insideTheIdealRangeItFits() {
        #expect(ShareNetworkLine.text(for: .tiktok, aspect: "9:16", isVertical: true, seconds: 52, ideal: ideal) == "9:16 · 0:52 FITS")
    }

    @Test func outsideItSaysHowFarOff() {
        #expect(ShareNetworkLine.text(for: .reels, aspect: "9:16", isVertical: true, seconds: 90, ideal: ideal).hasSuffix("OVER"))
        #expect(ShareNetworkLine.text(for: .shorts, aspect: "9:16", isVertical: true, seconds: 12, ideal: ideal).hasSuffix("UNDER"))
    }

    @Test func aVerticalVideoOfThreeMinutesOrLessPostsToYouTubeAsAShort() {
        #expect(ShareNetworkLine.text(for: .youtube, aspect: "9:16", isVertical: true, seconds: 52, ideal: ideal) == "9:16 · POSTS AS A SHORT")
        #expect(ShareNetworkLine.text(for: .youtube, aspect: "9:16", isVertical: true, seconds: 180, ideal: ideal).hasSuffix("POSTS AS A SHORT"))
        #expect(!ShareNetworkLine.text(for: .youtube, aspect: "9:16", isVertical: true, seconds: 181, ideal: ideal).contains("SHORT"))
        #expect(!ShareNetworkLine.text(for: .youtube, aspect: "16:9", isVertical: false, seconds: 52, ideal: ideal).contains("SHORT"))
    }

    @Test func theFiveNetworksArePickable() {
        #expect(ShareNetworkLine.networks == [.tiktok, .reels, .shorts, .youtube, .linkedin])
    }
}
