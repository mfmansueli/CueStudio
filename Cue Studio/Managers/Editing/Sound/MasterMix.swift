//
//  MasterMix.swift
//  Cue Studio
//

import AVFoundation

/// The last step of an export that mixes more than the take's sound (music, voice-overs, a
/// video's own sound): the mix is rendered once, as the export would hear it, through a peak
/// limiter and checked against `AudioCeiling`, and the export takes that one sound track instead
/// of mixing on its own. Two loud things together can't clip.
nonisolated enum MasterMix {
    /// Every sound track of `composition` mixed as its audio mix says, limited, in place of them.
    /// Returns whether it did (then the audio mix no longer applies): a composition with one sound
    /// track or none is left as it is.
    @concurrent
    @discardableResult
    static func apply(to composition: EditedComposition) async throws -> Bool {
        let asset = composition.asset
        let tracks = asset.tracks.filter { $0.mediaType == .audio }
        guard tracks.count > 1 else { return false }
        let mixed = try await render(asset, tracks: tracks, audioMix: composition.audioMix)
        defer { try? FileManager.default.removeItem(at: mixed) }
        let limited = try AudioEnhancer.limit(mixed)
        let source = AVURLAsset(url: limited)
        guard let sound = try await source.loadTracks(withMediaType: .audio).first else { return false }
        let length = try await source.load(.duration)
        let duration = try await asset.load(.duration)
        for track in tracks { asset.removeTrack(track) }
        guard let track = asset.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return true }
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(length, duration)), of: sound, at: .zero)
        return true
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
        try reader.start()
        while let ready = try await provider.next() {
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
        return url
    }
}
