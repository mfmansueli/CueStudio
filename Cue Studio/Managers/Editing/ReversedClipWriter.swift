//
//  ReversedClipWriter.swift
//  Cue Studio
//

import AVFoundation
import CoreMedia

/// Reverse: a stretch of a recording written backwards, picture and sound, as a video of its own in the edit's media, so the
/// montage plays it as a clip like any other (cropped, looked, sped and exported the same way). The recording itself is never
/// touched. The picture is read a few frames at a time from the end (the frames of one step are held, never the whole clip:
/// about 100 MB at most, whatever the resolution), written at the recording's size, codec family and frame rate with its
/// orientation; the sound is read whole (a minute of stereo is about 23 MB) and written back to front.
nonisolated enum ReversedClipWriter {
    enum WriteError: Error { case noVideo, cantWrite, tooLong }

    /// Longest stretch reversed.
    static let longest: TimeInterval = 120
    /// Most memory the frames of one step take.
    static let stepBytes = 100_000_000

    /// Writes `span` of the recording at `url` backwards; returns the new file's name in `EditMediaFiles`. `progress` hears
    /// how far it is, 0 to 1.
    @concurrent
    static func write(_ url: URL, span: TimeSpan, progress: @escaping @Sendable (Double) -> Void) async throws -> String {
        guard span.duration <= longest + 0.001 else { throw WriteError.tooLong }
        let asset = AVURLAsset(url: url)
        guard let video = try await asset.loadTracks(withMediaType: .video).first else { throw WriteError.noVideo }
        let audio = try await asset.loadTracks(withMediaType: .audio).first
        let (size, transform, rate, dataRate) = try await video.load(.naturalSize, .preferredTransform, .nominalFrameRate, .estimatedDataRate)
        let (name, destination) = try EditMediaFiles.newFile(pathExtension: "mov")
        let picture = Picture(size: size, transform: transform, frameRate: Double(rate > 0 ? rate : 30), bitRate: Int(dataRate))
        do {
            try await write(asset: asset, audio: audio, span: span, picture: picture, to: destination, progress: progress)
        } catch {
            EditMediaFiles.remove([name])
            throw error
        }
        return name
    }

    /// A decoded frame held from the reader until it's written. Unchecked: the buffer is only read, by one task at a time
    /// (the reader made it, the writer reads it), and Core Video's buffers are safe to hand between threads.
    private struct Frame: @unchecked Sendable {
        let buffer: CVPixelBuffer

        /// A copy of `source` (its planes, row by row) in a buffer of its own.
        init?(copying source: CVPixelBuffer) {
            var made: CVPixelBuffer?
            let attributes: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()]
            CVPixelBufferCreate(
                nil, CVPixelBufferGetWidth(source), CVPixelBufferGetHeight(source), CVPixelBufferGetPixelFormatType(source),
                attributes as CFDictionary, &made
            )
            guard let made else { return nil }
            CVPixelBufferLockBaseAddress(source, .readOnly)
            CVPixelBufferLockBaseAddress(made, [])
            defer {
                CVPixelBufferUnlockBaseAddress(made, [])
                CVPixelBufferUnlockBaseAddress(source, .readOnly)
            }
            for plane in 0..<max(1, CVPixelBufferGetPlaneCount(source)) {
                let planar = CVPixelBufferIsPlanar(source)
                guard let from = planar ? CVPixelBufferGetBaseAddressOfPlane(source, plane) : CVPixelBufferGetBaseAddress(source),
                      let into = planar ? CVPixelBufferGetBaseAddressOfPlane(made, plane) : CVPixelBufferGetBaseAddress(made) else { return nil }
                let rows = planar ? CVPixelBufferGetHeightOfPlane(source, plane) : CVPixelBufferGetHeight(source)
                let fromStride = planar ? CVPixelBufferGetBytesPerRowOfPlane(source, plane) : CVPixelBufferGetBytesPerRow(source)
                let intoStride = planar ? CVPixelBufferGetBytesPerRowOfPlane(made, plane) : CVPixelBufferGetBytesPerRow(made)
                for row in 0..<rows {
                    memcpy(into + row * intoStride, from + row * fromStride, min(fromStride, intoStride))
                }
            }
            buffer = made
        }
    }

    /// How the recording's picture is: what the reversed one is written like.
    private struct Picture {
        let size: CGSize
        let transform: CGAffineTransform
        let frameRate: Double
        let bitRate: Int
    }

    private static func write(
        asset: AVURLAsset, audio: AVAssetTrack?, span: TimeSpan, picture: Picture, to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let (size, transform, frameRate, bitRate) = (picture.size, picture.transform, picture.frameRate, picture.bitRate)
        let width = Int(size.width) & ~1, height = Int(size.height) & ~1
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                // As sharp as the recording: its own data rate (at least about what the camera writes).
                AVVideoAverageBitRateKey: max(bitRate, width * height * 4),
                AVVideoExpectedSourceFrameRateKey: Int(frameRate.rounded()),
            ],
        ])
        videoInput.transform = transform
        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), size: CVImageSize(width: width, height: height)
        )
        let pixels = writer.inputPixelBufferReceiver(for: videoInput, pixelBufferAttributes: attributes)
        var sound: (receiver: AVAssetWriterInput.SampleBufferReceiver, samples: [Float], channels: Int, rate: Double)?
        if let audio, let read = try await ReversedSound.samples(of: asset, track: audio, span: span) {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: read.rate, AVNumberOfChannelsKey: read.channels, AVEncoderBitRateKey: 192_000,
            ])
            sound = (writer.inputReceiver(for: input), read.samples, read.channels, read.rate)
        }
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        async let pictures: Void = writePictures(
            of: asset.url, span: span, frameRate: frameRate, frameBytes: width * height * 3 / 2, into: pixels, progress: progress
        )
        async let written: Void = writeSound(sound)
        _ = try await (pictures, written)
        writer.endSession(atSourceTime: CMTime(seconds: span.duration, preferredTimescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? WriteError.cantWrite }
    }

    /// The frames from the end of `span` to its start, a step of frames at a time, each at its mirrored time.
    private static func writePictures(
        of url: URL, span: TimeSpan, frameRate: Double, frameBytes: Int,
        into pixels: AVAssetWriterInput.PixelBufferReceiver, progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: url)
        guard let video = try await asset.loadTracks(withMediaType: .video).first else { throw WriteError.noVideo }
        let framesPerStep = max(4, min(30, stepBytes / max(1, frameBytes)))
        let step = Double(framesPerStep) / frameRate
        var stepEnd = span.end
        var last = -Double.infinity
        while stepEnd > span.start + 0.000_1 {
            try Task.checkCancellation()
            let stepStart = max(span.start, stepEnd - step)
            var frames: [(Frame, TimeInterval)] = []
            let reader = try AVAssetReader(asset: asset)
            reader.timeRange = CMTimeRange(
                start: CMTime(seconds: stepStart, preferredTimescale: 600), end: CMTime(seconds: stepEnd, preferredTimescale: 600)
            )
            let output = AVAssetReaderTrackOutput(track: video, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            ])
            let provider = reader.outputProvider(for: output)
            try reader.start()
            while let ready = try await provider.next() {
                let frame = ready.withUnsafeSampleBuffer { sample -> (Frame, TimeInterval)? in
                    let time = sample.presentationTimeStamp.seconds
                    guard time >= stepStart - 0.000_1, time < stepEnd - 0.000_1, let buffer = sample.imageBuffer else { return nil }
                    // Copied out of the reader's pool: holding its own buffers would stall it.
                    return Frame(copying: buffer).map { ($0, time) }
                }
                if let frame { frames.append(frame) }
            }
            reader.cancelReading()
            for (frame, time) in frames.sorted(by: { $0.1 > $1.1 }) {
                // Mirrored: the stretch's last frame first. One frame's length after the end of the span is the start.
                let mirrored = max(0, span.end - time - 1 / frameRate)
                guard mirrored > last + 0.000_1 else { continue }
                last = mirrored
                try await pixels.append(CVReadOnlyPixelBuffer(unsafeBuffer: frame.buffer), with: CMTime(seconds: mirrored, preferredTimescale: 60_000))
            }
            progress(min(1, (span.end - stepStart) / max(0.001, span.duration)))
            stepEnd = stepStart
        }
        pixels.finish()
    }

    private static func writeSound(_ sound: (receiver: AVAssetWriterInput.SampleBufferReceiver, samples: [Float], channels: Int, rate: Double)?) async throws {
        guard let sound else { return }
        try await ReversedSound.append(sound.samples, channels: sound.channels, rate: sound.rate, to: sound.receiver)
        sound.receiver.finish()
    }
}
