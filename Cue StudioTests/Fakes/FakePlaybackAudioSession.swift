//
//  FakePlaybackAudioSession.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakePlaybackAudioSession: PlaybackAudioSession {
    private(set) var preparations = 0
    var delay: Duration?

    func prepareForPlayback() async {
        preparations += 1
        if let delay { try? await Task.sleep(for: delay) }
    }
}
