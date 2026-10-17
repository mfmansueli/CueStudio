//
//  StillClipWriter.swift
//  Cue Studio
//

import AVFoundation
import CoreGraphics
import CoreVideo
import VideoToolbox

/// Freeze frame: one frame of a recording, upright and at its size, written as a short silent video into the edit's media, so
/// the montage plays it as a clip of its own (cropped, looked and exported like any other recording). The recording itself is
/// never touched. A frame of an HDR recording stays HDR: the decoded frame itself (10 bits) in HEVC Main 10 with the
/// recording's color primaries, transfer function and matrix, so the editor converts it the way it converts the clips next
/// to it; an SDR one is an upright H.264 picture.
nonisolated enum StillClipWriter {
    enum WriteError: Error { case noFrame, cantWrite }

    /// Frames per second of the still: the compositor shows the latest one at any rate.
    static let frameRate: Int32 = 15

    /// Writes `length` seconds of the frame at `time` of the video at `url`, off the main actor (a 4K frame takes about 2 s).
    /// Returns the new file's name in `EditMediaFiles`.
    @concurrent
    static func write(frameOf url: URL, at time: TimeInterval, length: TimeInterval) async throws -> String {
        let asset = AVURLAsset(url: url)
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let characteristics = try? await track.load(.mediaCharacteristics), characteristics.contains(.containsHDRVideo) {
            // An HDR frame that can't be written as HDR (an encoder without Main 10) still freezes, in SDR.
            if let name = try? await writeHDR(frameOf: asset, track: track, at: time, length: length) { return name }
        }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let frame = try? await generator.image(at: CMTime(seconds: max(0, time), preferredTimescale: 600)).image else {
            throw WriteError.noFrame
        }
        let (name, destination) = try EditMediaFiles.newFile(pathExtension: "mov")
        do {
            try await write(frame, length: length, to: destination)
        } catch {
            EditMediaFiles.remove([name])
            throw error
        }
        return name
    }

    // MARK: - HDR

    /// The color the recording's frames are tagged with, for the writer (the same names in Core Media and AVFoundation).
    private struct HDRColor {
        let primaries: String
        let transfer: String
        let matrix: String

        init?(_ format: CMFormatDescription) {
            func value(_ key: CFString) -> String? { CMFormatDescriptionGetExtension(format, extensionKey: key) as? String }
            guard let transfer = value(kCMFormatDescriptionExtension_TransferFunction) else { return nil }
            self.transfer = transfer
            primaries = value(kCMFormatDescriptionExtension_ColorPrimaries) ?? (kCMFormatDescriptionColorPrimaries_ITU_R_2020 as String)
            matrix = value(kCMFormatDescriptionExtension_YCbCrMatrix) ?? (kCMFormatDescriptionYCbCrMatrix_ITU_R_2020 as String)
        }

        var settings: [String: String] {
            [AVVideoColorPrimariesKey: primaries, AVVideoTransferFunctionKey: transfer, AVVideoYCbCrMatrixKey: matrix]
        }
    }

    /// The decoded frame at `time`, 10 bits per component, written as it is (not rotated: the still keeps the recording's
    /// transform) for `length` seconds.
    private static func writeHDR(frameOf asset: AVURLAsset, track: AVAssetTrack, at time: TimeInterval, length: TimeInterval) async throws -> String {
        let (formats, transform) = try await track.load(.formatDescriptions, .preferredTransform)
        guard let format = formats.first, let color = HDRColor(format) else { throw WriteError.noFrame }
        let still = try await decodedFrame(of: asset, track: track, at: time, color: color)
        let (width, height) = still.withUnsafeBuffer { (CVPixelBufferGetWidth($0), CVPixelBufferGetHeight($0)) }
        let (name, destination) = try EditMediaFiles.newFile(pathExtension: "mov")
        do {
            let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: width, AVVideoHeightKey: height,
                AVVideoColorPropertiesKey: color.settings,
                AVVideoCompressionPropertiesKey: [AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel as String],
            ])
            input.transform = transform
            let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: nil)
            try writer.start()
            writer.startSession(atSourceTime: .zero)
            let count = max(2, Int((length * Double(frameRate)).rounded(.up)) + 1)
            for index in 0..<count {
                try await receiver.append(still, with: CMTime(value: CMTimeValue(index), timescale: frameRate))
            }
            receiver.finish()
            writer.endSession(atSourceTime: CMTime(seconds: length, preferredTimescale: 600))
            await writer.finishWriting()
            guard writer.status == .completed else { throw writer.error ?? WriteError.cantWrite }
        } catch {
            EditMediaFiles.remove([name])
            throw error
        }
        return name
    }

    /// The frame shown at `time` (or the first one after it), decoded to 10-bit 4:2:0 and copied into a buffer of its own,
    /// tagged with the recording's color (the decoder's buffer goes back to the reader).
    private static func decodedFrame(
        of asset: AVURLAsset, track: AVAssetTrack, at time: TimeInterval, color: HDRColor
    ) async throws -> CVReadOnlyPixelBuffer {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
        ])
        reader.timeRange = CMTimeRange(start: CMTime(seconds: max(0, time), preferredTimescale: 600), duration: .positiveInfinity)
        let provider = reader.outputProvider(for: output)
        try reader.start()
        defer { reader.cancelReading() }
        while let sample = try await provider.next() {
            let copied = sample.withUnsafeSampleBuffer { buffer -> CVReadOnlyPixelBuffer? in
                CMSampleBufferGetImageBuffer(buffer).flatMap { copy($0, color: color) }
            }
            if let copied { return copied }
        }
        throw WriteError.noFrame
    }

    /// A 10-bit 4:2:0 frame copied plane by plane, with the color tags the writer is told.
    private static func copy(_ frame: CVPixelBuffer, color: HDRColor) -> CVReadOnlyPixelBuffer? {
        guard CVPixelBufferGetPixelFormatType(frame) == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
              CVPixelBufferGetPlaneCount(frame) == 2 else { return nil }
        let size = CVImageSize(width: CVPixelBufferGetWidth(frame), height: CVPixelBufferGetHeight(frame))
        guard var copy = try? CVMutablePixelBuffer(CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange), size: size
        )) else { return nil }
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }
        let copied = copy.accessUnsafeMutableRawPlaneBytes { planes -> Bool in
            guard planes.count == 2 else { return false }
            for (index, plane) in planes.enumerated() {
                guard let source = CVPixelBufferGetBaseAddressOfPlane(frame, index), let destination = plane.bytes.baseAddress else { return false }
                let sourceRow = CVPixelBufferGetBytesPerRowOfPlane(frame, index)
                let rowBytes = min(sourceRow, plane.properties.bytesPerRow)
                for row in 0..<min(CVPixelBufferGetHeightOfPlane(frame, index), plane.properties.size.height) {
                    destination.advanced(by: row * plane.properties.bytesPerRow).copyMemory(from: source.advanced(by: row * sourceRow), byteCount: rowBytes)
                }
            }
            return true
        }
        guard copied else { return nil }
        copy.withUnsafeBuffer { buffer in
            CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, color.primaries as CFString, .shouldPropagate)
            CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, color.transfer as CFString, .shouldPropagate)
            CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, color.matrix as CFString, .shouldPropagate)
        }
        return CVReadOnlyPixelBuffer(copy)
    }

    // MARK: - SDR

    private static func write(_ frame: CGImage, length: TimeInterval, to destination: URL) async throws {
        // H.264 wants even sides.
        let width = frame.width & ~1, height = frame.height & ~1
        guard width > 0, height > 0 else { throw WriteError.noFrame }
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA), size: CVImageSize(width: width, height: height)
        )
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        let pool = try receiver.pixelBufferPool ?? CVMutablePixelBuffer.Pool(pixelBufferAttributes: attributes)
        var buffer = try pool.makeMutablePixelBuffer()
        buffer.accessUnsafeMutableRawPlaneBytes { planes in
            guard let plane = planes.first, let base = plane.bytes.baseAddress,
                  let context = CGContext(
                      data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: plane.properties.bytesPerRow,
                      space: frame.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                  ) else { return }
            context.draw(frame, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let still = CVReadOnlyPixelBuffer(buffer)
        let count = max(2, Int((length * Double(frameRate)).rounded(.up)) + 1)
        for index in 0..<count {
            try await receiver.append(still, with: CMTime(value: CMTimeValue(index), timescale: frameRate))
        }
        receiver.finish()
        writer.endSession(atSourceTime: CMTime(seconds: length, preferredTimescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? WriteError.cantWrite }
    }
}
