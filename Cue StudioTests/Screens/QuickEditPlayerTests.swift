//
//  QuickEditPlayerTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The real player on a real clip: the clock follows playback, stops at the end handle, stays
/// put on pause, and trims move only the playback window.
@MainActor
@Suite("QuickEditPlayer", .serialized, .timeLimit(.minutes(2)))
struct QuickEditPlayerTests {
    private func makePlayer(seconds: Int = 3) async throws -> (QuickEditPlayer, TakeEdit, URL) {
        let clip = try await TestClip.make(seconds: seconds)
        let player = QuickEditPlayer(videoURL: clip, editing: TakeEditService())
        let edit = TakeEdit(sourceDuration: TimeInterval(seconds), aspect: .portrait)
        player.show(edit)
        try await waitUntil { player.state == .ready }
        return (player, edit, clip)
    }

    private func waitUntil(timeout: Duration = .seconds(10), _ condition: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while !condition() {
            guard clock.now < deadline else {
                Issue.record("Timed out")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func itemSeconds(_ player: QuickEditPlayer) -> TimeInterval {
        player.avPlayer.currentTime().seconds
    }

    @Test func theFirstItemIsReadyAtTheStart() async throws {
        let (player, _, clip) = try await makePlayer()
        defer { try? FileManager.default.removeItem(at: clip) }
        #expect(player.currentTime == 0)
        #expect(!player.isPlaying)
        #expect(player.avPlayer.currentItem != nil)
        player.stop()
    }

    @Test func seekingGoesExactlyThere() async throws {
        let (player, _, clip) = try await makePlayer()
        defer { try? FileManager.default.removeItem(at: clip) }
        player.seek(to: 1.25)
        #expect(player.currentTime == 1.25)
        try await waitUntil { abs(itemSeconds(player) - 1.25) < 0.001 }
        player.stop()
    }

    @Test func playingMovesTheClockAndStopsAtTheEndHandle() async throws {
        let (player, edit, clip) = try await makePlayer(seconds: 3)
        defer { try? FileManager.default.removeItem(at: clip) }
        var trimmed = edit
        trimmed.timeline.trimEnd(to: 1)
        player.show(trimmed)
        player.play()
        #expect(player.isPlaying)
        try await waitUntil { player.currentTime > 0.3 }
        #expect(player.isPlaying)
        try await waitUntil { !player.isPlaying }
        #expect(abs(player.currentTime - 1) < 0.05)
        #expect(itemSeconds(player) <= 1.05)
        player.stop()
    }

    @Test func playingFromTheEndStartsAgain() async throws {
        let (player, _, clip) = try await makePlayer(seconds: 2)
        defer { try? FileManager.default.removeItem(at: clip) }
        player.seek(to: 2)
        try await waitUntil { abs(itemSeconds(player) - 2) < 0.05 }
        player.play()
        try await waitUntil { player.currentTime > 0.1 && player.currentTime < 1 }
        player.stop()
    }

    @Test func pauseLeavesThePlayheadOnTheShownFrame() async throws {
        let (player, _, clip) = try await makePlayer()
        defer { try? FileManager.default.removeItem(at: clip) }
        player.play()
        try await waitUntil { player.currentTime > 0.4 }
        player.pause()
        #expect(!player.isPlaying)
        #expect(abs(player.currentTime - itemSeconds(player)) < 0.005)
        // The player reports where it came to rest once; from then on the playhead holds still.
        try await Task.sleep(for: .milliseconds(200))
        let paused = player.currentTime
        #expect(abs(paused - itemSeconds(player)) < 0.001)
        try await Task.sleep(for: .milliseconds(500))
        #expect(player.currentTime == paused)
        player.stop()
    }

    @Test func scrubbingPausesAndFollowsTheFinger() async throws {
        let (player, _, clip) = try await makePlayer()
        defer { try? FileManager.default.removeItem(at: clip) }
        player.play()
        for time in [0.5, 1.1, 1.7, 2.2] { player.scrub(to: time) }
        #expect(!player.isPlaying)
        #expect(player.currentTime == 2.2)
        player.endScrub()
        try await waitUntil { abs(itemSeconds(player) - 2.2) < 0.001 }
        #expect(!player.isPlaying)
        player.stop()
    }

    @Test func aTrimMovesTheWindowWithoutRebuilding() async throws {
        let (player, edit, clip) = try await makePlayer()
        defer { try? FileManager.default.removeItem(at: clip) }
        let item = player.avPlayer.currentItem
        var trimmed = edit
        trimmed.timeline.trimStart(to: 1)
        trimmed.timeline.trimEnd(to: 2.5)
        player.show(trimmed)
        #expect(player.avPlayer.currentItem === item)
        #expect(abs((item?.forwardPlaybackEndTime.seconds ?? 0) - 2.5) < 0.01)
        // The edit starts one second into the recording.
        player.seek(to: 0.5)
        try await waitUntil { abs(itemSeconds(player) - 1.5) < 0.001 }
        player.stop()
    }

    @Test func removingAPieceRebuildsAndKeepsTheMoment() async throws {
        let (player, edit, clip) = try await makePlayer()
        defer { try? FileManager.default.removeItem(at: clip) }
        let item = player.avPlayer.currentItem
        var cut = edit
        cut.timeline.split(atEdited: 1)
        cut.timeline.split(atEdited: 2)
        player.show(cut)
        // A cut that removes nothing needs no new item.
        #expect(player.avPlayer.currentItem === item)
        player.seek(to: 2.5)
        var removed = cut
        removed.timeline.removeSegment(id: removed.timeline.segments[1].id)
        player.show(removed)
        #expect(abs(player.currentTime - 1.5) < 0.000_1)
        try await waitUntil { player.avPlayer.currentItem !== item && player.state == .ready }
        try await waitUntil { abs(itemSeconds(player) - 1.5) < 0.001 }
        player.stop()
    }

    @Test func removingWhilePlayingHoldsTheOldItemThenPlaysOn() async throws {
        let (player, edit, clip) = try await makePlayer()
        defer { try? FileManager.default.removeItem(at: clip) }
        var cut = edit
        cut.timeline.split(atEdited: 1)
        cut.timeline.split(atEdited: 2)
        player.show(cut)
        let item = player.avPlayer.currentItem
        player.play()
        try await waitUntil { player.currentTime > 0.3 }
        // The middle piece: removing the last one would only move the end handle.
        var removed = cut
        removed.timeline.removeSegment(id: removed.timeline.segments[1].id)
        player.show(removed)
        // The old item stops at once: its times no longer match the edit.
        #expect(player.avPlayer.rate == 0)
        #expect(player.isPlaying)
        try await waitUntil { player.avPlayer.currentItem !== item && player.avPlayer.rate > 0 }
        #expect(player.isPlaying)
        #expect(player.currentTime <= 2)
        player.stop()
    }

    @Test func aMissingFileFails() async throws {
        let player = QuickEditPlayer(videoURL: URL.temporaryDirectory.appending(path: "gone-\(UUID()).mov"), editing: TakeEditService())
        player.show(TakeEdit(sourceDuration: 3, aspect: .portrait))
        try await waitUntil { player.state == .failed }
        player.play()
        #expect(!player.isPlaying)
    }

    @Test func stopLetsGoOfTheVideo() async throws {
        let (player, _, clip) = try await makePlayer()
        defer { try? FileManager.default.removeItem(at: clip) }
        player.play()
        player.stop()
        #expect(!player.isPlaying)
        #expect(player.avPlayer.currentItem == nil)
    }
}
