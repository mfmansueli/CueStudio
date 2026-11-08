//
//  BackgroundCompositionTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Quick edit › Background through the whole preview: the edit's effect reaches the compositor and the frame the player shows changes
/// (`BackgroundCompositingTests` covers the drawing alone). A recording half green screen, half grey.
@MainActor
@Suite("Background in the edited composition", .timeLimit(.minutes(3)))
struct BackgroundCompositionTests {
    private let size = CGSize(width: SkinTestClip.width, height: SkinTestClip.height)

    private func greenScreenClip() async throws -> URL {
        let width = CGFloat(SkinTestClip.width), height = CGFloat(SkinTestClip.height)
        let screen = CIImage(color: CIColor(red: 0, green: 0.85, blue: 0.1)).cropped(to: CGRect(x: 0, y: 0, width: width / 2, height: height))
        let grey = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        return try await SkinTestClip.make(seconds: 2, picture: grey.composited(over: screen))
    }

    @concurrent
    private func image(_ asset: AVAsset, composition: AVVideoComposition?, at time: Double) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.videoComposition = composition
        generator.maximumSize = CGSize(width: SkinTestClip.width, height: SkinTestClip.height)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
    }

    /// RGB at (x, y) from the top left, in fractions of the frame.
    private func color(_ image: CGImage, x: CGFloat, y: CGFloat) throws -> [Int] {
        let width = Int(size.width), height = Int(size.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(origin: .zero, size: size))
        let index = (Int(y * size.height) * width + Int(x * size.width)) * 4
        return [Int(bytes[index]), Int(bytes[index + 1]), Int(bytes[index + 2])]
    }

    private func preview(_ effect: BackgroundEffect?, clip: URL) async throws -> CGImage {
        var edit = TakeEdit(sourceDuration: 2, aspect: .portrait)
        edit.voiceEnhancement = .off
        if let effect { edit.setBackground(effect, for: nil) }
        let item = try await TakeEditService().previewItem(forVideoAt: clip, edit: edit)
        return try await image(item.asset, composition: item.videoComposition, at: 1)
    }

    @Test func aColorKeyPutsTheColorWhereTheGreenScreenWas() async throws {
        let clip = try await greenScreenClip()
        defer { try? FileManager.default.removeItem(at: clip) }
        var effect = BackgroundEffect()
        effect.style = .color
        effect.color = .red
        effect.cutout = .colorKey
        let before = try await preview(nil, clip: clip)
        let after = try await preview(effect, clip: clip)
        let screen = try color(before, x: 0.25, y: 0.5)
        #expect(screen[1] > 150 && screen[0] < 80, "the recording: \(screen)")
        let keyed = try color(after, x: 0.25, y: 0.5)
        #expect(keyed[0] > 200 && keyed[1] < 120, "the green screen became \(keyed)")
        let grey = try color(after, x: 0.75, y: 0.5)
        #expect(abs(grey[0] - grey[1]) < 20 && grey[1] > 90 && grey[1] < 170, "the grey half became \(grey)")
    }

    /// A blue photo in the edit's media, removed after the test.
    private func bluePhoto() throws -> String {
        let name = "behind-\(UUID().uuidString).png"
        let url = EditMediaFiles.url(for: name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let blue = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: CGRect(x: 0, y: 0, width: 90, height: 160))
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try CIContext().writePNGRepresentation(of: blue, to: url, format: .RGBA8, colorSpace: space)
        return name
    }

    @Test func aPhotoBehindYouShowsAroundTheCreatorWhereTheyStand() async throws {
        let clip = try await greenScreenClip()
        let name = try bluePhoto()
        defer {
            try? FileManager.default.removeItem(at: clip)
            EditMediaFiles.remove([name])
        }
        var edit = TakeEdit(sourceDuration: 2, aspect: .portrait)
        edit.voiceEnhancement = .off
        // An Original background: the green screen's cutout serves the photo Behind you.
        edit.setBackground(BackgroundEffect(cutout: .colorKey), for: nil)
        var photo = MediaOverlay(kind: .photo, fileName: name, aspect: 90.0 / 160, mediaDuration: nil, span: TimeSpan(start: 0, end: 2))
        photo.layout = .behind
        edit.media = [photo]
        let item = try await TakeEditService().previewItem(forVideoAt: clip, edit: edit)
        let frame = try await image(item.asset, composition: item.videoComposition, at: 1)
        let screen = try color(frame, x: 0.25, y: 0.5)
        #expect(screen[2] > 200 && screen[1] < 90, "the green screen became \(screen), not the photo")
        let creator = try color(frame, x: 0.75, y: 0.5)
        #expect(abs(creator[0] - creator[1]) < 20 && creator[1] > 90 && creator[1] < 170, "the creator became \(creator)")

        // Half the size at the middle: the photo shows at the frame's edge where the creator stood.
        var smallerEffect = BackgroundEffect(cutout: .colorKey)
        smallerEffect.person = PersonPlacement(center: .center, scale: 0.5)
        edit.backgrounds = [RecordingBackground(sourceID: nil, effect: smallerEffect)]
        let smaller = try await TakeEditService().previewItem(forVideoAt: clip, edit: edit)
        let resized = try await image(smaller.asset, composition: smaller.videoComposition, at: 1)
        let edge = try color(resized, x: 0.9, y: 0.5)
        #expect(edge[2] > 200 && edge[1] < 90, "where the creator stood shows \(edge), not the photo")
        let still = try color(resized, x: 0.6, y: 0.5)
        #expect(abs(still[0] - still[1]) < 20 && still[1] > 90, "the smaller creator isn't at the middle: \(still)")
    }

    @Test func aColorKeyWithABlurPutsTheBlurredFrameThere() async throws {
        let clip = try await greenScreenClip()
        defer { try? FileManager.default.removeItem(at: clip) }
        var effect = BackgroundEffect()
        effect.style = .blur
        effect.blur = 1
        effect.cutout = .colorKey
        let before = try await preview(nil, clip: clip)
        let after = try await preview(effect, clip: clip)
        // Next to the edge the blurred frame mixes green and grey; the recording there is pure green.
        let edge = try color(after, x: 0.45, y: 0.5), plain = try color(before, x: 0.45, y: 0.5)
        #expect(edge != plain, "blur changed nothing at the edge: \(edge)")
    }
}
