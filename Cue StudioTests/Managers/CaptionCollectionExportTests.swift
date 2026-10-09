//
//  CaptionCollectionExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

extension RealExports {
    /// Real decoded output compared with the AVFoundation preview, including the active word.
    @MainActor
    @Suite("Caption collection exports", .serialized, .timeLimit(.minutes(10)))
    struct CaptionCollectionExportTests {
        private let frame = CGSize(width: 360, height: 640)
        // Read-only fixture shared by the serialized cases: avoid repeatedly starting a hardware
        // encoder on the simulator just to manufacture the identical source movie.
        private static var sourceClip: URL?
        private static var remainingStyles = CaptionTheme.allCases.count

        private func source() async throws -> URL {
            if let existing = Self.sourceClip { return existing }
            let clip = try await TestClip.make(seconds: 4)
            Self.sourceClip = clip
            Self.remainingStyles = CaptionTheme.allCases.count
            return clip
        }

        @concurrent
        private func image(_ asset: AVAsset, composition: AVVideoComposition?, at time: Double) async throws -> UIImage {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.videoComposition = composition
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            let generated = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
            return UIImage(cgImage: generated)
        }

        private func pixels(_ image: UIImage) throws -> [UInt8] {
            let cgImage = try #require(image.cgImage)
            var bytes = [UInt8](repeating: 0, count: 360 * 640 * 4)
            let context = try #require(CGContext(data: &bytes, width: 360, height: 640, bitsPerComponent: 8, bytesPerRow: 360 * 4,
                                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(origin: .zero, size: frame))
            return bytes
        }

        private func meanDifference(_ first: UIImage, _ second: UIImage) throws -> Double {
            let a = try pixels(first)
            let b = try pixels(second)
            let differences = zip(a, b).map { abs(Int($0) - Int($1)) }
            return Double(differences.reduce(0, +)) / Double(differences.count)
        }

        @Test(arguments: CaptionTheme.allCases)
        func burnedCaptionsMatchThePreviewAndDisappearAtTheirEnd(_ theme: CaptionTheme) async throws {
            Attachment.record("Starting source video generation", named: "\(theme.rawValue)-stage-1-source.txt")
            let clip = try await source()
            defer {
                Self.remainingStyles -= 1
                if Self.remainingStyles == 0 {
                    try? FileManager.default.removeItem(at: clip)
                    Self.sourceClip = nil
                }
            }
            Attachment.record("Source ready", named: "\(theme.rawValue)-stage-2-source-ready.txt")
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.showsCaptions = true
            edit.captionCollection = CaptionSettings(theme: theme)
            let words = ["Sua", "ideia", "merece", "ganhar", "vida."].enumerated().map { index, word in
                CaptionWord(text: word, start: 0.5 + Double(index) * 0.4, end: 0.8 + Double(index) * 0.4)
            }
            edit.captions = [CaptionCue(words: words)]
            let preview = try await TakeEditService().previewItem(forVideoAt: clip, edit: edit)
            Attachment.record("Preview composition ready", named: "\(theme.rawValue)-stage-3-preview-ready.txt")
            let output = try await VideoExportService().export(videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit, burnsInCaptions: true))
            defer { try? FileManager.default.removeItem(at: output) }
            Attachment.record("Movie exported", named: "\(theme.rawValue)-stage-4-export-ready.txt")
            let shown = try await image(preview.asset, composition: preview.videoComposition, at: 1.4)
            Attachment.record("Preview frame decoded", named: "\(theme.rawValue)-stage-5-preview-frame.txt")
            let exported = try await image(AVURLAsset(url: output), composition: nil, at: 1.4)
            let original = try await image(AVURLAsset(url: clip), composition: nil, at: 1.4)
            let previewDifference = try meanDifference(shown, exported)
            let captionDifference = try meanDifference(original, exported)
            #expect(previewDifference < 3)
            #expect(captionDifference > 0.15)
            Attachment.record("preview/export mean pixel difference: \(previewDifference); original/export: \(captionDifference)", named: "\(theme.rawValue)-metrics.txt")
            let after = try await image(AVURLAsset(url: output), composition: nil, at: 3.4)
            let untouched = try await image(AVURLAsset(url: clip), composition: nil, at: 3.4)
            #expect(try meanDifference(after, untouched) < 2)

            let folder = URL.temporaryDirectory.appending(path: "caption-validation", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try #require(shown.pngData()).write(to: folder.appending(path: "\(theme.rawValue)-preview.png"))
            try #require(exported.pngData()).write(to: folder.appending(path: "\(theme.rawValue)-export.png"))
            Attachment.record(try #require(shown.pngData()), named: "\(theme.rawValue)-preview.png")
            Attachment.record(try #require(exported.pngData()), named: "\(theme.rawValue)-export.png")
            try Data(contentsOf: output).write(to: folder.appending(path: "\(theme.rawValue).mov"))
        }

        /// A text's look copied onto the captions ("Apply this style to captions") burns in as the preview shows it,
        /// where the collection puts the lines, and goes away at the line's end.
        @Test func aCopiedLookExportsAsItPreviews() async throws {
            let clip = try await TestClip.make(seconds: 4)
            defer { try? FileManager.default.removeItem(at: clip) }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.showsCaptions = true
            edit.captionCollection?.center = OverlayPoint(x: 0.5, y: 0.3)
            edit.captionCollection?.customLook = TextLook(
                font: .dmSerif, weight: .regular, color: .lavender, background: .pill, backgroundColor: .black, hasShadow: false
            )
            let words = ["Sua", "ideia", "merece", "ganhar", "vida."].enumerated().map { index, word in
                CaptionWord(text: word, start: 0.5 + Double(index) * 0.4, end: 0.8 + Double(index) * 0.4)
            }
            edit.captions = [CaptionCue(words: words)]
            let preview = try await TakeEditService().previewItem(forVideoAt: clip, edit: edit)
            let output = try await VideoExportService().export(videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit, burnsInCaptions: true))
            defer { try? FileManager.default.removeItem(at: output) }
            let shown = try await image(preview.asset, composition: preview.videoComposition, at: 1.4)
            let exported = try await image(AVURLAsset(url: output), composition: nil, at: 1.4)
            let original = try await image(AVURLAsset(url: clip), composition: nil, at: 1.4)
            #expect(try meanDifference(shown, exported) < 3)
            #expect(try meanDifference(original, exported) > 0.15)
            let after = try await image(AVURLAsset(url: output), composition: nil, at: 3.4)
            let untouched = try await image(AVURLAsset(url: clip), composition: nil, at: 3.4)
            #expect(try meanDifference(after, untouched) < 2)
            Attachment.record(try #require(exported.pngData()), named: "copied-look-export.png")
        }

        @Test func disabledCaptionsExportWithoutAnyOverlay() async throws {
            let clip = try await TestClip.make(seconds: 2)
            defer { try? FileManager.default.removeItem(at: clip) }
            var edit = TakeEdit(sourceDuration: 2, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.showsCaptions = false
            edit.captions = [CaptionCue(text: "Hidden captions", start: 0, end: 2)]
            let output = try await VideoExportService().export(videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit, burnsInCaptions: true))
            defer { try? FileManager.default.removeItem(at: output) }
            let original = try await image(AVURLAsset(url: clip), composition: nil, at: 0.5)
            let exported = try await image(AVURLAsset(url: output), composition: nil, at: 0.5)
            #expect(try meanDifference(original, exported) < 2)
            #expect(FileManager.default.fileExists(atPath: clip.path))
        }
    }
}
