//
//  SoundExtractor.swift
//  Cue Studio
//

import AVFoundation

/// Extract audio: a stretch of a file's sound written as an AAC file of its own in the edit's media, at a clip's speed
/// (time-scaled, keeping the voice's pitch or not, as the preview plays it) or along its speed curve (rendered as the preview
/// and the export play it, `CurveSoundRenderer`), off the main actor. The file read is never changed.
nonisolated enum SoundExtractor {
    enum ExtractError: Error {
        case cantWrite
    }

    /// Writes `span` (seconds of the file at `url`) played at `speed`, or along `curve` when there's one. Throws
    /// `AudioTrackExtractor.ExtractError.noAudio` when the file has no sound.
    @concurrent
    static func write(from url: URL, span: TimeSpan, speed: Double, keepsPitch: Bool, curve: SpeedCurve? = nil) async throws -> ExtractedSound {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { throw AudioTrackExtractor.ExtractError.noAudio }
        let fileLength = try await asset.load(.duration).seconds
        let start = max(0, span.start)
        let end = min(span.end, fileLength.isFinite ? fileLength : span.end)
        guard end - start >= 0.05 else { throw AudioTrackExtractor.ExtractError.noAudio }
        if let curve {
            let rendered = try await CurveSoundRenderer.render(
                file: url, trackID: track.trackID, span: TimeSpan(start: start, end: end), curve: curve, keepsPitch: keepsPitch,
                clip: "extracted"
            )
            return try await export(AVURLAsset(url: rendered), pitch: .spectral, length: curve.editedLength(sourceLength: end - start))
        }
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
        return try await export(composition, pitch: keepsPitch ? .spectral : .varispeed, length: played)
    }

    /// `asset`'s sound written as AAC into the edit's media.
    private static func export(_ asset: AVAsset, pitch: AVAudioTimePitchAlgorithm, length: TimeInterval) async throws -> ExtractedSound {
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioTrackExtractor.ExtractError.exportUnavailable
        }
        session.audioTimePitchAlgorithm = pitch
        let (name, destination) = try EditMediaFiles.newFile(pathExtension: "m4a")
        do {
            try await session.export(to: destination, as: .m4a)
        } catch {
            EditMediaFiles.remove([name])
            throw error
        }
        return ExtractedSound(fileName: name, duration: length)
    }
}
