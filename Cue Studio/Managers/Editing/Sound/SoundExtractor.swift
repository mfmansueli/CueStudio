//
//  SoundExtractor.swift
//  Cue Studio
//

import AVFoundation

/// Extract audio: a stretch of a file's sound written as an AAC file of its own in the edit's media, at a clip's speed
/// (time-scaled, keeping the voice's pitch or not, as the preview plays it), off the main actor. The file read is never
/// changed.
nonisolated enum SoundExtractor {
    enum ExtractError: Error {
        case cantWrite
    }

    /// Writes `span` (seconds of the file at `url`) played at `speed`. Throws `AudioTrackExtractor.ExtractError.noAudio`
    /// when the file has no sound.
    @concurrent
    static func write(from url: URL, span: TimeSpan, speed: Double, keepsPitch: Bool) async throws -> ExtractedSound {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { throw AudioTrackExtractor.ExtractError.noAudio }
        let fileLength = try await asset.load(.duration).seconds
        let start = max(0, span.start)
        let end = min(span.end, fileLength.isFinite ? fileLength : span.end)
        guard end - start >= 0.05 else { throw AudioTrackExtractor.ExtractError.noAudio }
        let composition = AVMutableComposition()
        guard let sound = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExtractError.cantWrite
        }
        let length = CMTime(seconds: end - start, preferredTimescale: 48_000)
        try sound.insertTimeRange(CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 48_000), duration: length), of: track, at: .zero)
        let speed = EditSegment.clampedSpeed(speed)
        let played = (end - start) / speed
        if abs(speed - 1) > 0.000_1 {
            composition.scaleTimeRange(CMTimeRange(start: .zero, duration: length), toDuration: CMTime(seconds: played, preferredTimescale: 48_000))
        }
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioTrackExtractor.ExtractError.exportUnavailable
        }
        session.audioTimePitchAlgorithm = keepsPitch ? .spectral : .varispeed
        let (name, destination) = try EditMediaFiles.newFile(pathExtension: "m4a")
        do {
            try await session.export(to: destination, as: .m4a)
        } catch {
            EditMediaFiles.remove([name])
            throw error
        }
        return ExtractedSound(fileName: name, duration: played)
    }
}
