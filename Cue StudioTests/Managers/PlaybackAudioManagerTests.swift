//
//  PlaybackAudioManagerTests.swift
//  Cue StudioTests
//

import AVFAudio
import Testing
@testable import Cue_Studio

@MainActor
@Suite("PlaybackAudioManager", .serialized)
struct PlaybackAudioManagerTests {
    @Test func videoPlaybackUsesTheCategoryThatIgnoresTheSilentSwitch() async throws {
        let session = AVAudioSession.sharedInstance()
        let category = session.category
        let mode = session.mode
        let options = session.categoryOptions
        do {
            try await Task.detached { try AVAudioSession.sharedInstance().setCategory(.soloAmbient) }.value
            await PlaybackAudioManager().prepareForPlayback()
            #expect(session.category == .playback)
            #expect(session.mode == .moviePlayback)
            #expect(session.categoryOptions.isEmpty)

            // Capture takes ownership again; the next playback must not inherit its mic route.
            try await Task.detached { try AudioRoute.configureForCapture() }.value
            #expect(session.category == .playAndRecord)
            #expect(session.mode == .videoRecording)
            #expect(session.categoryOptions.contains(.defaultToSpeaker))
            #expect(session.categoryOptions.contains(.allowBluetoothHFP))
            await PlaybackAudioManager().prepareForPlayback()
            #expect(session.category == .playback)
            #expect(session.mode == .moviePlayback)
            #expect(session.categoryOptions.isEmpty)
        } catch {
            await restore(category: category, mode: mode, options: options)
            throw error
        }
        await restore(category: category, mode: mode, options: options)
    }

    private func restore(category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) async {
        await Task.detached {
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try? session.setCategory(category, mode: mode, options: options)
        }.value
    }
}
