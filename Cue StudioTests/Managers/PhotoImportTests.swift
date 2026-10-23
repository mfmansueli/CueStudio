//
//  PhotoImportTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Cue_Studio

/// A photo comes in upright and no larger than 2160 px, read at that size from the file; a small one keeps its size.
@Suite("Photo import")
struct PhotoImportTests {
    /// A JPEG `width` × `height` whose metadata says to turn it (6: a quarter turn, as an iPhone held upright writes).
    private static func photo(width: Int, height: Int, orientation: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func aBigTurnedPhotoComesInUprightAndSmaller() throws {
        let imported = try EditMediaImporter.storePhoto(try Self.photo(width: 4032, height: 3024, orientation: 6))
        defer { EditMediaFiles.remove([imported.fileName]) }
        // Held upright: taller than wide once turned.
        #expect(abs(imported.aspect - 3024.0 / 4032.0) < 0.01)
        let source = try #require(CGImageSourceCreateWithURL(EditMediaFiles.url(for: imported.fileName) as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 2160)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 1620)
    }

    @Test func aSmallPhotoKeepsItsSize() throws {
        let imported = try EditMediaImporter.storePhoto(try Self.photo(width: 800, height: 600, orientation: 1))
        defer { EditMediaFiles.remove([imported.fileName]) }
        let source = try #require(CGImageSourceCreateWithURL(EditMediaFiles.url(for: imported.fileName) as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 800)
        #expect(abs(imported.aspect - 800.0 / 600.0) < 0.01)
    }

    @Test func somethingThatIsntAPhotoIsRefused() {
        #expect(throws: EditMediaImportError.self) { try EditMediaImporter.storePhoto(Data("not a photo".utf8)) }
    }
}
