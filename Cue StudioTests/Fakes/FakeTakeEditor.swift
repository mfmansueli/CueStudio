//
//  FakeTakeEditor.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
@testable import Cue_Studio

@MainActor
final class FakeTakeEditor: TakeEditing {
    /// Nil: the recording is missing.
    var duration: TimeInterval? = 64
    var silences: [TimeSpan] = [TimeSpan(start: 10, end: 12), TimeSpan(start: 30, end: 31)]
    var captions: [CaptionCue] = [CaptionCue(text: "Okay, real talk.", start: 0, end: 1)]
    private(set) var captionScript: String?

    func sourceDuration(ofVideoAt url: URL) async throws -> TimeInterval {
        guard let duration else { throw EditSourceError.missing }
        return duration
    }

    func silences(inVideoAt url: URL) async throws -> [TimeSpan] { silences }

    func captions(forVideoAt url: URL, script: String, duration: TimeInterval) async -> [CaptionCue] {
        captionScript = script
        return captions
    }

    func previewItem(forVideoAt url: URL, edit: TakeEdit) async throws -> AVPlayerItem {
        AVPlayerItem(url: url)
    }
}
