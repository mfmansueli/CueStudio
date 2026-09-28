//
//  QuickEditPreviewPlayerTests.swift
//  Cue StudioTests
//

import AVFoundation
import Testing
@testable import Cue_Studio

/// Quick edit's preview rebuilds its player item after every change. Opening Quick edit crashed
/// because the first build sought an empty player's (invalid) time, which raises an exception.
@MainActor
@Suite("Quick edit preview player")
struct QuickEditPreviewPlayerTests {
    @Test func theFirstItemGoesInWithoutSeekingToAnInvalidTime() async {
        let player = AVPlayer()
        #expect(!player.currentTime().isNumeric)
        let item = AVPlayerItem(url: URL.temporaryDirectory.appending(path: "take-\(UUID().uuidString).mov"))

        await player.replaceCurrentItemKeepingTime(with: item)

        #expect(player.currentItem === item)
    }
}
