//
//  HDRTestClip.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
import VideoToolbox

/// An HDR clip like an iPhone's: HEVC Main 10, BT.2020 primaries and matrix, HLG, written from 10-bit frames, one flat color
/// (in Y′CbCr) per second, turned a quarter (`preferredTransform`) as a portrait recording is.
enum HDRTestClip {
    /// Y′, Cb, Cr (10-bit, video range) of each second.
    static let colors: [(y: UInt16, cb: UInt16, cr: UInt16)] = [(300, 400, 700), (600, 650, 380), (820, 512, 512), (180, 700, 450)]
    static let framesPerSecond: Int32 = 30
    static let size = (width: 640, height: 360)
    static let transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: CGFloat(360), ty: 0)

    static func make(seconds: Int) async throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "hdr-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: size.width, AVVideoHeightKey: size.height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
            ],
            AVVideoCompressionPropertiesKey: [AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel as String],
        ])
        input.transform = transform
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange),
            size: CVImageSize(width: size.width, height: size.height)
        ))
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        let pool = try #require(receiver.pixelBufferPool)
        for frame in 0..<(seconds * Int(framesPerSecond)) {
            let color = colors[frame / Int(framesPerSecond) % colors.count]
            try await receiver.append(try buffer(color, pool: pool), with: CMTime(value: CMTimeValue(frame), timescale: framesPerSecond))
        }
        receiver.finish()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        return url
    }

    /// The center sample of the frame at `time`, decoded to 10 bits: Y′, Cb and Cr.
    static func centerSample(at time: TimeInterval, in url: URL) async throws -> (y: Int, cb: Int, cr: Int) {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
        ])
        reader.timeRange = CMTimeRange(start: CMTime(seconds: time, preferredTimescale: 600), duration: .positiveInfinity)
        let provider = reader.outputProvider(for: output)
        try reader.start()
        defer { reader.cancelReading() }
        let sample = try #require(try await provider.next())
        let center = sample.withUnsafeSampleBuffer { buffer -> [Int]? in
            guard let frame = CMSampleBufferGetImageBuffer(buffer) else { return nil }
            return centerValues(of: frame)
        }
        let values = try #require(center)
        return (values[0], values[1], values[2])
    }

    /// Y′, Cb and Cr at the middle of a 10-bit frame.
    private static func centerValues(of frame: CVPixelBuffer) -> [Int]? {
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }
        let width = CVPixelBufferGetWidth(frame), height = CVPixelBufferGetHeight(frame)
        guard let luma = CVPixelBufferGetBaseAddressOfPlane(frame, 0)?.assumingMemoryBound(to: UInt8.self),
              let chroma = CVPixelBufferGetBaseAddressOfPlane(frame, 1)?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let lumaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 0), chromaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 1)
        func value(_ base: UnsafeMutablePointer<UInt8>, _ offset: Int) -> Int {
            Int(UInt16(base[offset]) | UInt16(base[offset + 1]) << 8) >> 6
        }
        let chromaOffset = (height / 4) * chromaRow + (width / 4) * 4
        return [value(luma, (height / 2) * lumaRow + (width / 2) * 2), value(chroma, chromaOffset), value(chroma, chromaOffset + 2)]
    }

    private static func buffer(_ color: (y: UInt16, cb: UInt16, cr: UInt16), pool: CVMutablePixelBuffer.Pool) throws -> CVReadOnlyPixelBuffer {
        var buffer = try pool.makeMutablePixelBuffer()
        buffer.accessUnsafeMutableRawPlaneBytes { planes in
            guard planes.count == 2 else { return }
            // 10 bits in the high bits of each little-endian 16-bit sample.
            for (index, plane) in planes.enumerated() {
                guard let base = plane.bytes.baseAddress else { continue }
                let rows = plane.properties.size.height
                let samples = index == 0 ? plane.properties.size.width : plane.properties.size.width * 2
                for row in 0..<rows {
                    let line = base.advanced(by: row * plane.properties.bytesPerRow).assumingMemoryBound(to: UInt16.self)
                    for sample in 0..<samples {
                        let value = index == 0 ? color.y : (sample.isMultiple(of: 2) ? color.cb : color.cr)
                        line[sample] = (value << 6).littleEndian
                    }
                }
            }
        }
        return CVReadOnlyPixelBuffer(buffer)
    }
}
