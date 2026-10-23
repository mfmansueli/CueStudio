//
//  RenderParity.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Testing

/// Two pictures of the same moment compared the way an eye would: both drawn at one small size, then the mean difference of
/// their channels (0 the same, 255 opposite). For the tests that hold the preview, the export and the cover to one picture.
enum RenderParity {
    /// The frame of `asset` at `time`, drawn with `composition` (nil: as written).
    @concurrent
    static func frame(_ asset: AVAsset, composition: AVVideoComposition?, at time: Double) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.videoComposition = composition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
    }

    /// RGBA of `image` drawn at `size`.
    static func pixels(_ image: CGImage, size: CGSize) throws -> [UInt8] {
        let width = Int(size.width), height = Int(size.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return bytes
    }

    static func meanDifference(_ first: CGImage, _ second: CGImage, size: CGSize) throws -> Double {
        let differences = zip(try pixels(first, size: size), try pixels(second, size: size)).map { abs(Int($0) - Int($1)) }
        return Double(differences.reduce(0, +)) / Double(max(1, differences.count))
    }
}
