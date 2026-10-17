//
//  BackgroundDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Quick edit › Background behind a real person, with the real Vision segmentation, on this device (the Simulator finds no one: its mask is nil).
/// Uses the same portrait as `SkinSmoothingDeviceTests`; the results are printed as `BACKGROUND …` lines and kept with the test.
///
/// Opt-in: `TEST_RUNNER_CUE_SKIN_E2E=1 TEST_RUNNER_CUE_SKIN_MEDIA=Documents/skin.jpg CUE_DEVICE=<iPhone> scripts/test.sh device BackgroundDeviceTests`.
@MainActor
@Suite(
    "Background behind a real person",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_SKIN_E2E"] != nil),
    .timeLimit(.minutes(10))
)
struct BackgroundDeviceTests {
    private let size = CGSize(width: SkinTestClip.width, height: SkinTestClip.height)

    private func photo() throws -> CIImage {
        let path = try #require(ProcessInfo.processInfo.environment["CUE_SKIN_MEDIA"], "CUE_SKIN_MEDIA names the photo")
        let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : URL.homeDirectory.appending(path: path)
        let image = try #require(CIImage(contentsOf: url, options: [.applyOrientationProperty: true]), "no photo at \(url.path)")
        return image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
    }

    /// The photo filling a portrait frame, as a selfie take has it.
    private func framed(_ photo: CIImage) -> CIImage {
        let scale = max(size.width / photo.extent.width, size.height / photo.extent.height)
        let scaled = photo.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return scaled
            .transformed(by: CGAffineTransform(translationX: (size.width - scaled.extent.width) / 2, y: (size.height - scaled.extent.height) / 2))
            .cropped(to: CGRect(origin: .zero, size: size))
    }

    private func note(_ line: String) {
        print(line)
        Attachment.record(line, named: "BACKGROUND \(abs(line.hashValue)).txt")
    }

    /// The share of the mask that is the person (above half).
    private func personShare(_ mask: CIImage) throws -> Double {
        let width = 90, height = 160
        let small = mask.transformed(by: CGAffineTransform(scaleX: CGFloat(width) / mask.extent.width, y: CGFloat(height) / mask.extent.height))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        CIContext().render(small, toBitmap: &bytes, rowBytes: width * 4, bounds: bounds, format: .RGBA8, colorSpace: nil)
        let person = stride(from: 0, to: bytes.count, by: 4).filter { bytes[$0] > 127 }.count
        return Double(person) / Double(width * height)
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

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        let width = Int(size.width), height = Int(size.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return bytes
    }

    private func meanDifference(_ first: CGImage, _ second: CGImage) throws -> Double {
        let differences = zip(try pixels(first), try pixels(second)).map { abs(Int($0) - Int($1)) }
        return Double(differences.reduce(0, +)) / Double(differences.count)
    }

    @Test func thisIPhoneFindsThePersonInThePhoto() async throws {
        let canFind = await BackgroundSupport.canFindPeople()
        note("BACKGROUND support check (64 pt grey frame): \(canFind)")
        #expect(canFind, "the panel would say this iPhone can't find people")
        let mask = try #require(PersonMasker.mask(for: framed(try photo())), "Vision found no one in the photo")
        let share = try personShare(mask)
        note("BACKGROUND person in the frame: \(Int(share * 100))%")
        #expect(share > 0.05 && share < 0.95, "the mask is \(Int(share * 100))% person")
    }

    @Test(arguments: [BackgroundStyle.blur, .color])
    func thePreviewChangesBehindThePerson(_ style: BackgroundStyle) async throws {
        let clip = try await SkinTestClip.make(seconds: 2, picture: framed(try photo()))
        defer { try? FileManager.default.removeItem(at: clip) }
        var edit = TakeEdit(sourceDuration: 2, aspect: .portrait)
        edit.voiceEnhancement = .off
        let before = try await TakeEditService().previewItem(forVideoAt: clip, edit: edit)
        var effect = BackgroundEffect()
        effect.style = style
        effect.blur = 1
        effect.color = .blue
        edit.setBackground(effect, for: nil)
        let after = try await TakeEditService().previewItem(forVideoAt: clip, edit: edit)
        let plain = try await image(before.asset, composition: before.videoComposition, at: 1)
        let changed = try await image(after.asset, composition: after.videoComposition, at: 1)
        let difference = try meanDifference(plain, changed)
        note("BACKGROUND \(style): mean difference \(String(format: "%.1f", difference)) of 255")
        Attachment.record(UIImage(cgImage: changed).pngData() ?? Data(), named: "background-\(style).png")
        #expect(difference > 4, "the \(style) background changed nothing")
    }
}
