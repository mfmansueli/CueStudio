//
//  Mixdown.swift
//  Cue Studio
//

import AVFoundation

/// The last step of an export that mixes more than the take's sound (music, voice-overs, a
/// video's own sound): the mix is rendered once, as the export would hear it, through a peak
/// limiter and checked against `AudioCeiling`, and the export takes that one sound track instead
/// of mixing on its own. Two loud things together can't clip. A cancel stops it at once and leaves
/// no file behind.
nonisolated enum Mixdown {
    /// The mixed file an export plays (`apply`), named apart from Studio Voice's sounds: it is the export's alone.
    static let filePrefix = "Cue-mixdown-"

    /// Whether `composition` plays more than one sound track, so an export mixes it down first.
    static func isNeeded(for composition: EditedComposition) -> Bool {
        composition.asset.tracks.count(where: { $0.mediaType == .audio }) > 1
    }

    /// Every sound track of `composition` mixed as its audio mix says, limited, in place of them.
    /// Returns the mixed file the composition now plays (then the audio mix no longer applies), nil
    /// when it was left as it is (one sound track or none). The file is the caller's alone: it is
    /// removed once the video is written, however the export ends (`VideoExportService`).
    @concurrent
    static func apply(to composition: EditedComposition) async throws -> URL? {
        let asset = composition.asset
        let tracks = asset.tracks.filter { $0.mediaType == .audio }
        guard tracks.count > 1 else { return nil }
        let mixed = try await render(asset, tracks: tracks, audioMix: composition.audioMix)
        defer { try? FileManager.default.removeItem(at: mixed) }
        try Task.checkCancellation()
        let limited = try AudioEnhancer.limit(mixed, prefix: filePrefix)
        do {
            try Task.checkCancellation()
            let source = AVURLAsset(url: limited)
            guard let sound = try await source.loadTracks(withMediaType: .audio).first else {
                try? FileManager.default.removeItem(at: limited)
                return nil
            }
            let length = try await source.load(.duration)
            let duration = try await asset.load(.duration)
            try Task.checkCancellation()
            for track in tracks { asset.removeTrack(track) }
            guard let track = asset.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return limited }
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(length, duration)), of: sound, at: .zero)
            return limited
        } catch {
            try? FileManager.default.removeItem(at: limited)
            throw error
        }
    }

    /// The composition's sound mixed down to one 48 kHz stereo file, as an export would mix it.
    @concurrent
    static func render(_ asset: AVAsset, tracks: [AVAssetTrack], audioMix: AVAudioMix?) async throws -> URL {
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: settings)
        output.audioMix = audioMix
        // Like the preview and the export: sped-up pieces keep the voice's pitch.
        output.audioTimePitchAlgorithm = .spectral
        let provider = reader.outputProvider(for: output)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: true) else {
            throw AudioEnhancer.RenderError.noBuffer
        }
        let url = URL.temporaryDirectory.appending(path: "Cue-master-\(UUID().uuidString.prefix(8)).caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: true)
        do {
            try reader.start()
            while let ready = try await provider.next() {
                // A cancelled export stops here, between two buffers: the reader stops and the half-written mix goes.
                try Task.checkCancellation()
                try ready.withUnsafeSampleBuffer { sample in
                    let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sample))
                    guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
                    buffer.frameLength = frames
                    let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
                        sample, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList
                    )
                    guard status == noErr else { throw AudioEnhancer.RenderError.renderFailed }
                    try file.write(from: buffer)
                }
            }
            try Task.checkCancellation()
        } catch {
            reader.cancelReading()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        return url
    }
}
