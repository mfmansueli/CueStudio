//
//  DebugLibrarySeed.swift
//  Cue Studio
//

#if DEBUG
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// `-uiTestSeedLibrary`: the media library starts with a logo ("Cue logo": yellow on a clear background) and a photo ("Studio
/// wall"), drawn here, for the UI tests of the library and the brand kits.
enum DebugLibrarySeed {
    @MainActor
    static func seed(into library: MediaLibraryStore) async {
        guard library.assets.isEmpty else { return }
        for (name, seeThrough) in [("Cue logo", true), ("Studio wall", false)] {
            guard let file = picture(seeThrough: seeThrough) else { continue }
            _ = try? await library.add(fileAt: file, name: name)
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func picture(seeThrough: Bool) -> URL? {
        let width = seeThrough ? 400 : 1080, height = seeThrough ? 200 : 1350
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        if seeThrough {
            context.setFillColor(CGColor(red: 1, green: 0.84, blue: 0.04, alpha: 1))
            context.fillEllipse(in: CGRect(x: 20, y: 20, width: 160, height: 160))
            context.fill(CGRect(x: 200, y: 70, width: 180, height: 60))
        } else {
            context.setFillColor(CGColor(red: 0.2, green: 0.24, blue: 0.4, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.setFillColor(CGColor(red: 0.95, green: 0.6, blue: 0.3, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height / 3))
        }
        guard let image = context.makeImage() else { return nil }
        let url = URL.temporaryDirectory.appending(path: "seed-\(UUID().uuidString).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? url : nil
    }
}
#endif
