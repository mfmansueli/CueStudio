//
//  ReviewPlaybackTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The review's player on a real clip, while the screen is recorded or mirrored: capture that starts during playback pauses it on
/// the same frame, capture already on refuses the first play, nothing that was on its way (the audio session getting ready, the
/// system) starts it while held, and capture ending leaves it paused where it was.
@MainActor
@Suite("ReviewPlayback", .serialized, .timeLimit(.minutes(2)))
struct ReviewPlaybackTests {
    /// One clip for the suite; every test plays its own copy.
    private static var fixture: Task<URL, Error>?

    private func makePlayback(audioSession: FakePlaybackAudioSession = FakePlaybackAudioSession()) async throws -> (ReviewPlayback, URL) {
        if Self.fixture == nil { Self.fixture = Task { try await TestClip.make(seconds: 3) } }
        let source = try await Self.fixture!.value
        let clip = URL.temporaryDirectory.appending(path: "review-\(UUID()).mov")
        try FileManager.default.copyItem(at: source, to: clip)
        let playback = ReviewPlayback(audioSession: audioSession)
        playback.load(AVPlayerItem(url: clip))
        await Wait.until { playback.player.currentItem?.status == .readyToPlay }
        return (playback, clip)
    }

    private func seconds(_ playback: ReviewPlayback) -> TimeInterval {
        playback.player.currentTime().seconds
    }

    private func finish(_ playback: ReviewPlayback, _ clip: URL) {
        playback.pause()
        playback.player.replaceCurrentItem(with: nil)
        try? FileManager.default.removeItem(at: clip)
    }

    @Test func playsOnceTheAudioSessionIsReady() async throws {
        let audioSession = FakePlaybackAudioSession()
        let (playback, clip) = try await makePlayback(audioSession: audioSession)
        defer { finish(playback, clip) }
        playback.play()
        #expect(playback.isPlaying)
        await Wait.until { seconds(playback) > 0.2 }
        #expect(audioSession.preparations == 1)
    }

    @Test func captureAlreadyOnRefusesTheFirstPlay() async throws {
        let audioSession = FakePlaybackAudioSession()
        let (playback, clip) = try await makePlayback(audioSession: audioSession)
        defer { finish(playback, clip) }
        playback.isPlaybackBlocked = true
        playback.play()
        playback.toggle()
        try await Task.sleep(for: .milliseconds(300))
        #expect(!playback.isPlaying)
        #expect(playback.player.rate == 0)
        #expect(seconds(playback) == 0)
        #expect(audioSession.preparations == 0)
    }

    @Test func captureStartingDuringPlaybackPausesOnTheSameFrame() async throws {
        let (playback, clip) = try await makePlayback()
        defer { finish(playback, clip) }
        playback.play()
        await Wait.until { seconds(playback) > 0.3 }
        playback.isPlaybackBlocked = true
        #expect(!playback.isPlaying)
        #expect(playback.player.rate == 0)
        let held = seconds(playback)
        try await Task.sleep(for: .milliseconds(300))
        #expect(abs(seconds(playback) - held) < 0.01)
    }

    @Test func anAudioSessionReadyAfterCaptureStartsDoesNotPlay() async throws {
        let audioSession = FakePlaybackAudioSession()
        audioSession.delay = .milliseconds(500)
        let (playback, clip) = try await makePlayback(audioSession: audioSession)
        defer { finish(playback, clip) }
        playback.play()
        await Wait.until { audioSession.preparations == 1 }
        playback.isPlaybackBlocked = true
        // Long past the moment the session is ready.
        try await Task.sleep(for: .milliseconds(900))
        #expect(!playback.isPlaying)
        #expect(playback.player.rate == 0)
        #expect(seconds(playback) == 0)
    }

    @Test func aPlayerStartedBehindItsBackStopsWhileHeld() async throws {
        let (playback, clip) = try await makePlayback()
        defer { finish(playback, clip) }
        let follower = Task { await playback.follow { 3 } }
        defer { follower.cancel() }
        playback.isPlaybackBlocked = true
        playback.player.play()
        await Wait.until { playback.player.rate == 0 && !playback.isPlaying }
    }

    @Test func seekingWhileHeldKeepsThePosition() async throws {
        let (playback, clip) = try await makePlayback()
        defer { finish(playback, clip) }
        playback.seek(to: 0.5, of: 3)
        await Wait.until { abs(seconds(playback) - 1.5) < 0.01 }
        playback.isPlaybackBlocked = true
        playback.seek(to: 0.1, of: 3)
        #expect(playback.progress == 0.5)
        try await Task.sleep(for: .milliseconds(200))
        #expect(abs(seconds(playback) - 1.5) < 0.01)
    }

    @Test func captureEndingRestoresThePositionWithoutPlaying() async throws {
        let (playback, clip) = try await makePlayback()
        defer { finish(playback, clip) }
        playback.player.isMuted = true
        playback.play()
        await Wait.until { seconds(playback) > 0.3 }
        playback.isPlaybackBlocked = true
        let held = seconds(playback)
        playback.isPlaybackBlocked = false
        try await Task.sleep(for: .milliseconds(400))
        #expect(!playback.isPlaying)
        #expect(playback.player.rate == 0)
        #expect(abs(seconds(playback) - held) < 0.01)
        #expect(playback.player.isMuted)
        // The creator plays it again from there.
        playback.play()
        await Wait.until { seconds(playback) > held + 0.2 }
    }

    @Test func theVideoNeverGoesToAnAirPlayReceiver() {
        #expect(!ReviewPlayback(audioSession: FakePlaybackAudioSession()).player.allowsExternalPlayback)
    }
}
