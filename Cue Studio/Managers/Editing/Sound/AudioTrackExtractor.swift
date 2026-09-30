//
//  AudioTrackExtractor.swift
//  Cue Studio
//

import AVFoundation

/// Copies a take's sound to an audio-only file that AVAudioFile and speech recognition can read.
nonisolated enum AudioTrackExtractor {
    enum ExtractError: Error {
        case noAudio
        case exportUnavailable
    }

    static func extract(from video: URL) async throws -> URL {
        let asset = AVURLAsset(url: video)
        guard try await !asset.loadTracks(withMediaType: .audio).isEmpty else { throw ExtractError.noAudio }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ExtractError.exportUnavailable
        }
        let output = URL.temporaryDirectory.appending(path: "Cue-audio-\(UUID().uuidString.prefix(8)).m4a")
        try await session.export(to: output, as: .m4a)
        return output
    }
}
