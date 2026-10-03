//
//  QuickEditPlayerTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// The real player on a real clip: the clock follows playback, stops at the end handle (or at the
/// end of the part under review), stays put on pause, and trims move only the playback window. A
/// new look keeps the item; new pieces swap it with the picture held on screen.
@MainActor
@Suite("QuickEditPlayer", .serialized, .timeLimit(.minutes(2)))
struct QuickEditPlayerTests {
    /// How many times the player asked a view to hold its picture.
    @MainActor
    private final class Holds {
        var count = 0
    }

    /// The Simulator can't draw a custom video composition while it plays (AVFoundation -12784):
    /// tests that look at drawn frames run on a device.
    private nonisolated static let drawsFrames: Bool = {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }()

    // Repeatedly starting the simulator's H.264 writer can stall before playback is exercised.
    // Keep immutable sources per duration; every test owns and deletes its own file copy.
    private static var fixtureTasks: [Int: Task<URL, Error>] = [:]

    private func makePlayer(
        seconds: Int = 3, audioSession: FakePlaybackAudioSession = FakePlaybackAudioSession(), editing: TakeEditing = TakeEditService()
    ) async throws -> (QuickEditPlayer, TakeEdit, URL) {
        if Self.fixtureTasks[seconds] == nil {
            Self.fixtureTasks[seconds] = Task { try await TestClip.make(seconds: seconds) }
        }
        let fixture = try await Self.fixtureTasks[seconds]!.value
        let clip = URL.temporaryDirectory.appending(path: "player-\(UUID()).mov")
        try FileManager.default.copyItem(at: fixture, to: clip)
        let player = QuickEditPlayer(videoURL: clip, editing: editing, audioSession: audioSession)
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

    /// The preview's view in the app's window, so the player draws frames.
    private func showOnScreen(_ player: QuickEditPlayer) -> FrameHoldingPlayerView {
        let view = FrameHoldingPlayerView(frame: CGRect(x: 0, y: 0, width: 90, height: 160))
        view.player = player.avPlayer
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .addSubview(view)
        return view
    }

    /// The filter the item draws with.
    private func drawnFilter(_ player: QuickEditPlayer) -> VideoFilter? {
        (player.avPlayer.currentItem?.videoComposition?.instructions.first as? CompositionInstruction)?.edit.filter
    }

    /// The middle of the frame the item drew last.
    private func drawnColor(_ player: QuickEditPlayer) -> [Int]? {
        guard let compositor = player.avPlayer.currentItem?.customVideoCompositor as? CueVideoCompositor,
              let frame = compositor.lastFrame() else { return nil }
        return try? TestClip.centerColor(of: frame)
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

    @Test func playingInsideThePartUnderReviewStopsAtItsEnd() async throws {
        let (player, _, clip) = try await makePlayer(seconds: 3)
        defer { try? FileManager.default.removeItem(at: clip) }
        player.reviewedPart = 0.5...1.2
        player.seek(to: 0.7)
        try await waitUntil { abs(itemSeconds(player) - 0.7) < 0.001 }
        player.play()
        try await waitUntil { player.currentTime > 0.9 }
        #expect(player.isPlaying)
        try await waitUntil { !player.isPlaying }
        #expect(abs(player.currentTime - 1.2) < 0.001)
        try await waitUntil { abs(itemSeconds(player) - 1.2) < 0.001 }
        // It stays there: nothing past the part plays.
        try await Task.sleep(for: .milliseconds(300))
        #expect(abs(player.currentTime - 1.2) < 0.001)
        #expect(!player.isPlaying)
        player.stop()
    }

    @Test func playingFromThePartsEndPlaysThePartAgain() async throws {
        let (player, _, clip) = try await makePlayer(seconds: 3)
        defer { try? FileManager.default.removeItem(at: clip) }
        player.reviewedPart = 0.5...1
        player.seek(to: 1)
        try await waitUntil { abs(itemSeconds(player) - 1) < 0.001 }
        player.play()
        #expect(player.currentTime == 0.5)
        try await waitUntil { !player.isPlaying }
        #expect(abs(player.currentTime - 1) < 0.001)
        player.stop()
    }

    @Test func playingAfterThePartRunsToTheEnd() async throws {
        let (player, _, clip) = try await makePlayer(seconds: 2)
        defer { try? FileManager.default.removeItem(at: clip) }
        player.reviewedPart = 0.2...0.5
        player.seek(to: 1.2)
        try await waitUntil { abs(itemSeconds(player) - 1.2) < 0.001 }
        player.play()
        try await waitUntil { !player.isPlaying }
        #expect(abs(player.currentTime - 2) < 0.05)
        player.stop()
    }

    @Test func droppingThePartLetsPlaybackRunOn() async throws {
        let (player, _, clip) = try await makePlayer(seconds: 3)
        defer { try? FileManager.default.removeItem(at: clip) }
        player.reviewedPart = 0...1
        player.play()
        try await waitUntil { player.currentTime > 0.2 }
        player.reviewedPart = nil
        try await waitUntil { player.currentTime > 1.3 }
        #expect(player.isPlaying)
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

    @Test func aLookChangeKeepsTheItemAndTakesTheNewDrawing() async throws {
        let (player, edit, clip) = try await makePlayer()
        defer {
            player.stop()
            try? FileManager.default.removeItem(at: clip)
        }
        let item = player.avPlayer.currentItem
        var mono = edit
        mono.filter = .mono
        player.show(mono)
        try await waitUntil { drawnFilter(player) == .mono }
        #expect(player.avPlayer.currentItem === item)
    }

    @Test(.enabled(if: drawsFrames, "Needs a device to draw frames"))
    func aLookChangeRedrawsThePausedFrame() async throws {
        let (player, edit, clip) = try await makePlayer()
        let view = showOnScreen(player)
        defer {
            view.removeFromSuperview()
            player.stop()
            try? FileManager.default.removeItem(at: clip)
        }
        // The first second is red.
        try await waitUntil { drawnColor(player).map { $0[0] > 150 && $0[1] < 100 } ?? false }
        var mono = edit
        mono.filter = .mono
        player.show(mono)
        // The frame on screen is drawn again, gray.
        try await waitUntil { drawnColor(player).map { abs($0[0] - $0[1]) < 20 && abs($0[1] - $0[2]) < 20 } ?? false }
    }

    @Test(.enabled(if: drawsFrames, "Needs a device to draw frames"))
    func newPiecesHoldThePictureUntilTheNewItemShowsItsOwn() async throws {
        let (player, edit, clip) = try await makePlayer()
        let view = showOnScreen(player)
        defer {
            view.removeFromSuperview()
            player.stop()
            try? FileManager.default.removeItem(at: clip)
        }
        let holds = Holds()
        player.addFrameHolder(view) { [weak view] frame in
            holds.count += 1
            view?.hold(frame)
        }
        try await waitUntil { drawnColor(player) != nil }
        var looked = edit
        looked.filter = .mono
        player.show(looked)
        try await waitUntil { drawnFilter(player) == .mono }
        // A new look needs no new item, so nothing is held.
        #expect(holds.count == 0)

        let item = player.avPlayer.currentItem
        var removed = looked
        removed.timeline.split(atEdited: 1)
        removed.timeline.split(atEdited: 2)
        removed.timeline.removeSegment(id: removed.timeline.segments[1].id)
        player.show(removed)
        try await waitUntil { player.avPlayer.currentItem !== item }
        #expect(holds.count == 1)
        #expect(view.isHoldingFrame)
        // Let go once the layer shows the new item's own picture.
        try await waitUntil { !view.isHoldingFrame }
        #expect((view.layer as? AVPlayerLayer)?.isReadyForDisplay == true)
    }

    @Test func changesInARowBuildOnlyTheNewestAfterTheOneRunning() async throws {
        let editing = CountingTakeEditor(wrapping: TakeEditService())
        let (player, edit, clip) = try await makePlayer(editing: editing)
        defer {
            player.stop()
            try? FileManager.default.removeItem(at: clip)
        }
        let before = editing.previewItems
        for filter in [VideoFilter.mono, .warm, .cool, .film, .fade, .vivid, .natural, .cinema] {
            var changed = edit
            changed.filter = filter
            player.show(changed)
        }
        try await waitUntil { drawnFilter(player) == .cinema }
        // The first change builds at once; the others wait for it and are built together.
        #expect(editing.previewItems - before == 2)
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

    @Test func audiblePlaybackPreparesAudioAgainAfterPausing() async throws {
        let audioSession = FakePlaybackAudioSession()
        let (player, _, clip) = try await makePlayer(audioSession: audioSession)
        defer { player.stop(); try? FileManager.default.removeItem(at: clip) }
        #expect(audioSession.preparations == 0)
        player.play()
        try await waitUntil { player.currentTime > 0.1 }
        #expect(audioSession.preparations == 1)
        player.pause()
        player.play()
        try await waitUntil { audioSession.preparations == 2 }
    }

    @Test func mutedVoiceOverPlaybackDoesNotReplaceTheRecordingSession() async throws {
        let audioSession = FakePlaybackAudioSession()
        let (player, _, clip) = try await makePlayer(audioSession: audioSession)
        defer { player.stop(); try? FileManager.default.removeItem(at: clip) }
        player.isMuted = true
        player.play()
        try await waitUntil { player.currentTime > 0.1 }
        #expect(audioSession.preparations == 0)
        player.pause()
        player.isMuted = false
        player.play()
        try await waitUntil { audioSession.preparations == 1 }
    }

    @Test func pausingDuringAudioActivationDoesNotRestartPlayback() async throws {
        let audioSession = FakePlaybackAudioSession()
        audioSession.delay = .seconds(1)
        let (player, _, clip) = try await makePlayer(audioSession: audioSession)
        defer { player.stop(); try? FileManager.default.removeItem(at: clip) }
        player.play()
        try await waitUntil { audioSession.preparations == 1 }
        player.pause()
        try await Task.sleep(for: .milliseconds(100))
        #expect(!player.isPlaying)
        #expect(player.avPlayer.rate == 0)
    }

    @Test func seekingDuringAudioActivationStillResumesAtTheRequestedFrame() async throws {
        let audioSession = FakePlaybackAudioSession()
        audioSession.delay = .milliseconds(200)
        let (player, _, clip) = try await makePlayer(audioSession: audioSession)
        defer { player.stop(); try? FileManager.default.removeItem(at: clip) }
        player.play()
        try await waitUntil { audioSession.preparations == 1 }
        player.seek(to: 1)
        try await waitUntil { player.currentTime > 1.1 }
        #expect(player.isPlaying)
        #expect(audioSession.preparations >= 2)
    }

    @Test func closingDuringAudioActivationDoesNotRestartThePlayer() async throws {
        let audioSession = FakePlaybackAudioSession()
        audioSession.delay = .seconds(1)
        let (player, _, clip) = try await makePlayer(audioSession: audioSession)
        defer { try? FileManager.default.removeItem(at: clip) }
        player.play()
        try await waitUntil { audioSession.preparations == 1 }
        player.stop()
        try await Task.sleep(for: .milliseconds(100))
        #expect(!player.isPlaying)
        #expect(player.avPlayer.rate == 0)
        #expect(player.avPlayer.currentItem == nil)
    }
}
