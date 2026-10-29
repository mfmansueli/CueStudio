//
//  SoundPreviewPlayerTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// Hearing a sound effect, a library track or a narration makes the playback session ready first (off the main thread, past the
/// Ring/Silent switch), and a preview stopped or replaced meanwhile never starts.
@MainActor
@Suite("SoundPreviewPlayer")
struct SoundPreviewPlayerTests {
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func aPreviewMakesThePlaybackSessionReadyAndShowsWhatPlays() async {
        let session = FakePlaybackAudioSession()
        let previews = SoundPreviewPlayer(audioSession: session)
        previews.play(.ding)
        #expect(previews.playingKey == SoundEffect.ding.rawValue)
        await waitUntil { session.preparations == 1 }
        #expect(session.preparations == 1)
        #expect(previews.playingKey == SoundEffect.ding.rawValue)
        previews.stop()
        #expect(previews.playingKey == nil)
    }

    @Test func aPreviewStoppedWhileTheSessionGetsReadyNeverStarts() async throws {
        let session = FakePlaybackAudioSession()
        session.delay = .milliseconds(200)
        let previews = SoundPreviewPlayer(audioSession: session)
        previews.play(.drumRoll)
        previews.stop()
        try await Task.sleep(for: .milliseconds(400))
        #expect(previews.playingKey == nil)
    }

    @Test func aNewPreviewReplacesTheLast() async throws {
        let session = FakePlaybackAudioSession()
        session.delay = .milliseconds(100)
        let previews = SoundPreviewPlayer(audioSession: session)
        previews.play(.pop)
        previews.play(.drumRoll)
        #expect(previews.playingKey == SoundEffect.drumRoll.rawValue)
        try await Task.sleep(for: .milliseconds(300))
        #expect(previews.playingKey == SoundEffect.drumRoll.rawValue)
        previews.stop()
    }
}
