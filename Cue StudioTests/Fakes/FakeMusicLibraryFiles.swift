//
//  FakeMusicLibraryFiles.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
@testable import Cue_Studio

/// The library's files without the bundle's music: a second of silence written once per track in a folder of its own, after
/// `delay` (cancellable), or `failure` thrown.
nonisolated final class FakeMusicLibraryFiles: MusicLibraryFiles {
    private let delay: Duration
    private let failure: (any Error)?
    private let folder: URL

    init(delay: Duration = .zero, failure: (any Error)? = nil) {
        self.delay = delay
        self.failure = failure
        folder = FileManager.default.temporaryDirectory.appending(path: "FakeMusicLibrary-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    func file(for track: CueTrack) async throws -> URL {
        if delay > .zero { try await Task.sleep(for: delay) }
        try Task.checkCancellation()
        if let failure { throw failure }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "\(track.rawValue).caf")
        if !FileManager.default.fileExists(atPath: url.path) { try Self.writeSilence(to: url) }
        return url
    }

    private static func writeSilence(to url: URL) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000) else { throw CocoaError(.fileWriteUnknown) }
        buffer.frameLength = 48_000
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    func removeAll() { try? FileManager.default.removeItem(at: folder) }
}
