//
//  LogoOverVideosExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Cue_Studio

extension RealExports {
    /// A still logo over three videos at once (the most the editor lets show, the logo aside): the preview and the export both
    /// draw all three videos in their windows and the logo on top, its see-through half showing the take under it.
    @MainActor
    @Suite("A logo over three videos", .serialized, .timeLimit(.minutes(10)))
    struct LogoOverVideosExportTests {
        /// The logo's color: a light one, which the export's compression keeps (a saturated magenta comes out 37 greener).
        private static let logoColor = [240, 240, 240]
        private static let cyan = [40, 200, 210]

        /// A 40 × 20 PNG: light gray on its left half, see-through on its right.
        private func logoFile() throws -> URL {
            let context = try #require(CGContext(
                data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            let color = Self.logoColor
            context.setFillColor(CGColor(red: CGFloat(color[0]) / 255, green: CGFloat(color[1]) / 255, blue: CGFloat(color[2]) / 255, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
            let url = URL.temporaryDirectory.appending(path: "logo-\(UUID().uuidString).png")
            let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
            #expect(CGImageDestinationFinalize(destination))
            return url
        }

        /// The take (red over blue, 4 s); three videos in windows from 1 to 3 s, left, middle and right; the logo top right over
        /// the whole video. Points sampled are each window's middle and the logo's two halves.
        private func edit(fileNames videos: [String], logo: String) -> TakeEdit {
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            let centers = [OverlayPoint(x: 0.2, y: 0.3), OverlayPoint(x: 0.5, y: 0.6), OverlayPoint(x: 0.8, y: 0.85)]
            edit.media = zip(videos, centers).enumerated().map { index, pair in
                var media = MediaOverlay(kind: .video, fileName: pair.0, aspect: 9.0 / 16, mediaDuration: 4, span: TimeSpan(start: 1, end: 3))
                media.layout = .window
                media.width = 0.3
                media.center = pair.1
                media.layer = index + 1
                return media
            }
            var mark = MediaOverlay(kind: .photo, fileName: logo, aspect: 2, mediaDuration: nil, span: TimeSpan(start: 0, end: 4))
            mark.layout = .window
            mark.width = 0.3
            mark.center = OverlayPoint(x: 0.8, y: 0.1)
            mark.isLogo = true
            mark.layer = 4
            edit.media.append(mark)
            return edit
        }

        /// Where to look, and what should be there, at 2 s.
        private var expected: [(point: CGPoint, color: [Int], what: String)] {
            [
                (CGPoint(x: 0.2, y: 0.3), TwoToneClip.green, "the first video"),
                (CGPoint(x: 0.5, y: 0.6), TwoToneClip.yellow, "the second video"),
                (CGPoint(x: 0.8, y: 0.85), Self.cyan, "the third video"),
                (CGPoint(x: 0.7, y: 0.1), Self.logoColor, "the logo's picture"),
                (CGPoint(x: 0.9, y: 0.1), TwoToneClip.red, "the take through the logo's see-through half"),
            ]
        }

        @Test func thePreviewAndTheExportDrawThreeVideosAndTheLogoOverThem() async throws {
            let take = try await TwoToneClip.make(seconds: 4, top: TwoToneClip.red, bottom: TwoToneClip.blue)
            let clips = [
                try await TwoToneClip.make(seconds: 4, top: TwoToneClip.green, bottom: TwoToneClip.green),
                try await TwoToneClip.make(seconds: 4, top: TwoToneClip.yellow, bottom: TwoToneClip.yellow),
                try await TwoToneClip.make(seconds: 4, top: Self.cyan, bottom: Self.cyan),
            ]
            let logoURL = try logoFile()
            defer { (clips + [take, logoURL]).forEach { try? FileManager.default.removeItem(at: $0) } }
            let videos = try clips.map { try EditMediaFiles.link($0) }
            let logo = try EditMediaFiles.link(logoURL)
            defer { EditMediaFiles.remove(Set(videos + [logo])) }
            let edit = edit(fileNames: videos, logo: logo)
            #expect(edit.media.filter { !$0.isStaticLogo }.count == MediaOverlay.simultaneousLimit)

            // The export.
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 360, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            for spot in expected {
                let color = try await TwoToneClip.color(at: spot.point, time: 2, in: output)
                #expect(TwoToneClip.same(color, spot.color), "export, \(spot.what): \(color)")
            }

            // The editor's preview, the same frame.
            let item = try await TakeEditService().previewItem(forVideoAt: take, edit: edit, purpose: .editorPreview(rendersCurveSound: true))
            let generator = AVAssetImageGenerator(asset: item.asset)
            generator.videoComposition = item.videoComposition
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            let image = try await generator.image(at: CMTime(seconds: 2, preferredTimescale: 600)).image
            let width = image.width, height = image.height
            let context = try #require(CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
            for spot in expected {
                let offset = Int(spot.point.y * CGFloat(height)) * width * 4 + Int(spot.point.x * CGFloat(width)) * 4
                let color = [Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2])]
                #expect(TwoToneClip.same(color, spot.color), "preview, \(spot.what): \(color)")
            }
        }
    }
}
