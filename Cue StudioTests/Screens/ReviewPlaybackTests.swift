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

    @Test func theVideoNeverGoesToAnAirPlayReceiver() {
        #expect(!ReviewPlayback(audioSession: FakePlaybackAudioSession()).player.allowsExternalPlayback)
    }
}
