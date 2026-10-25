//
//  LibraryFileReader.swift
//  Cue Studio
//

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

/// Reads a library file as Cue will draw it: a video's shape, length and sound; a picture's upright shape and whether it is
/// see-through (a logo on a clear background). A file that doesn't read is missing or unreadable, said on its card.
nonisolated enum LibraryFileReader {
    struct Description: Equatable, Sendable {
        var kind: LibraryAssetKind
        var aspect: Double
        var duration: TimeInterval?
        var hasSound = false
    }

    enum Status: Equatable, Sendable {
        case ready
        /// The file is gone (restored from a backup without it, removed by hand).
        case missing
        /// The file is there but doesn't read as a picture or a video any more.
        case unreadable
    }

    static func describe(_ url: URL) async throws -> Description {
        if let picture = picture(at: url) { return picture }
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw EditMediaImportError.unreadable }
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
        let duration = try await asset.load(.duration).seconds
        let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
        guard duration.isFinite, duration > 0, upright.height != 0 else { throw EditMediaImportError.unreadable }
        let hasSound = (try? await asset.loadTracks(withMediaType: .audio).isEmpty == false) ?? false
        return Description(kind: .video, aspect: abs(upright.width / upright.height), duration: duration, hasSound: hasSound)
    }

    static func status(of url: URL, kind: LibraryAssetKind) async -> Status {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return .missing }
        if kind != .video { return picture(at: url) == nil ? .unreadable : .ready }
        let readable = (try? await AVURLAsset(url: url).loadTracks(withMediaType: .video).isEmpty == false) ?? false
        return readable ? .ready : .unreadable
    }

    /// A picture's description; nil when the file isn't one.
    static func picture(at url: URL) -> Description? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue, width > 0, height > 0 else { return nil }
        // EXIF orientations 5 to 8 turn the picture a quarter.
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let aspect = orientation >= 5 ? height / width : width / height
        return Description(kind: isSeeThrough(source) ? .logo : .photo, aspect: aspect)
    }

    /// Whether some of the picture is transparent, read on a small copy of it.
    static func isSeeThrough(_ source: CGImageSource) -> Bool {
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 64]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return false }
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return false }
        return stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] < 250 }
    }
}
