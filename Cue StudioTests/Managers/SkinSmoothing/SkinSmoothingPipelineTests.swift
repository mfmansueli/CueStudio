//
//  SkinSmoothingPipelineTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

extension RealExports {
    /// Skin Smoothing through the editor's own pipeline (the video compositor, with a fake that finds the drawn face): the preview and the export smooth
    /// the same frame the same way, and at 0 the video is the one the editor always made.
    @MainActor
    @Suite("Skin Smoothing through the editor", .serialized, .timeLimit(.minutes(10)))
    struct SkinSmoothingPipelineTests {
        private let size = CGSize(width: 360, height: 640)
        /// Where the drawn face sits in the 360-wide frame, and a patch of its cheek (the fixture is 480 wide, so everything moves 60 px left).
        private let shift = CGPoint(x: -60, y: 0)
        private var cheek: CGRect { SkinFaceFixture.cheek.offsetBy(dx: shift.x, dy: shift.y) }

        @concurrent
        private func image(_ asset: AVAsset, composition: AVVideoComposition?, at time: Double) async throws -> UIImage {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.videoComposition = composition
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            return UIImage(cgImage: try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image)
        }

        private func pixels(_ image: UIImage) throws -> RenderedPixels {
            RenderedPixels(CIImage(cgImage: try #require(image.cgImage)))
        }

        /// The cheek's texture in a frame of any size (the patch scales with the frame).
        private func texture(_ frame: RenderedPixels) -> Double {
            let scale = CGFloat(frame.width) / size.width
            return frame.texture(in: CGRect(x: cheek.minX * scale, y: cheek.minY * scale, width: cheek.width * scale, height: cheek.height * scale))
        }

        /// How far apart two pictures are, on average per channel, drawn at the same size.
        private func meanDifference(_ first: UIImage, _ second: UIImage) throws -> Double {
            func bytes(_ image: UIImage) throws -> [UInt8] {
                let cgImage = try #require(image.cgImage)
                var data = [UInt8](repeating: 0, count: Int(size.width) * Int(size.height) * 4)
                let context = try #require(CGContext(
                    data: &data, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: Int(size.width) * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ))
                context.draw(cgImage, in: CGRect(origin: .zero, size: size))
                return data
            }
            let differences = zip(try bytes(first), try bytes(second)).map { abs(Int($0) - Int($1)) }
            return Double(differences.reduce(0, +)) / Double(differences.count)
        }

        @Test func thePreviewAndTheExportSmoothTheSameFrameTheSameWay() async throws {
            let previous = SkinSmoother.makeDetector
            let landmarks = SkinFaceFixture.landmarks(shiftedBy: shift, in: size)
            SkinSmoother.makeDetector = { FakeFaceDetector(faces: [landmarks]) }
            defer { SkinSmoother.makeDetector = previous }
            let picture = SkinFaceFixture.image(shiftedBy: shift, texture: 2).cropped(to: CGRect(origin: .zero, size: size))
            let clip = try await SkinTestClip.make(seconds: 1, picture: picture)
            defer { try? FileManager.default.removeItem(at: clip) }
            var smoothed = TakeEdit(sourceDuration: 1, aspect: .portrait)
            smoothed.voiceEnhancement = .off
            smoothed.skinSmoothing = 100
            var plain = smoothed
            plain.skinSmoothing = 0

            let service = TakeEditService()
            let previewSmoothed = try await service.previewItem(forVideoAt: clip, edit: smoothed)
            let previewPlain = try await service.previewItem(forVideoAt: clip, edit: plain)
            let exporter = VideoExportService()
            let exportedSmoothed = try await exporter.export(
                videoAt: clip, options: ExportOptions(aspect: .portrait, edit: smoothed, shortSide: 720, frameRate: 30)
            )
            let exportedPlain = try await exporter.export(
                videoAt: clip, options: ExportOptions(aspect: .portrait, edit: plain, shortSide: 720, frameRate: 30)
            )
            defer {
                try? FileManager.default.removeItem(at: exportedSmoothed)
                try? FileManager.default.removeItem(at: exportedPlain)
            }

            for time in [0.25, 0.8] {
                let shownSmoothed = try await image(previewSmoothed.asset, composition: previewSmoothed.videoComposition, at: time)
                let shownPlain = try await image(previewPlain.asset, composition: previewPlain.videoComposition, at: time)
                let writtenSmoothed = try await image(AVURLAsset(url: exportedSmoothed), composition: nil, at: time)
                let writtenPlain = try await image(AVURLAsset(url: exportedPlain), composition: nil, at: time)
                // The export is what the preview shows, with smoothing on and with it off.
                let difference = try meanDifference(shownSmoothed, writtenSmoothed)
                #expect(difference < 3, "preview and export differ at \(time) s: \(difference)")
                #expect(try meanDifference(shownPlain, writtenPlain) < 3)
                // It smooths in both, and only the skin: the same frame without it is rougher on the cheek.
                #expect(texture(try pixels(shownSmoothed)) < texture(try pixels(shownPlain)) * 0.93, "the preview isn't smoothed at \(time) s")
                #expect(texture(try pixels(writtenSmoothed)) < texture(try pixels(writtenPlain)) * 0.93, "the export isn't smoothed at \(time) s")
                Attachment.record(try #require(writtenSmoothed.pngData()), named: "smoothed-\(time).png")
                Attachment.record(try #require(writtenPlain.pngData()), named: "plain-\(time).png")
            }
        }

        @Test func atZeroTheDetectorIsNeverAskedAndTheVideoIsTheOneAlwaysMade() async throws {
            let previous = SkinSmoother.makeDetector
            let detector = FakeFaceDetector(faces: [SkinFaceFixture.landmarks(shiftedBy: shift, in: size)])
            SkinSmoother.makeDetector = { detector }
            defer { SkinSmoother.makeDetector = previous }
            let picture = SkinFaceFixture.image(shiftedBy: shift).cropped(to: CGRect(origin: .zero, size: size))
            let clip = try await SkinTestClip.make(seconds: 1, picture: picture)
            defer { try? FileManager.default.removeItem(at: clip) }
            var edit = TakeEdit(sourceDuration: 1, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.contrast = 10
            let item = try await TakeEditService().previewItem(forVideoAt: clip, edit: edit)
            _ = try await image(item.asset, composition: item.videoComposition, at: 0.4)
            #expect(detector.calls == 0, "with the dial at 0 nothing looks for a face")
        }
    }
}
