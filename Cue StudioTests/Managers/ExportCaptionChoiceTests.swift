//
//  ExportCaptionChoiceTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

extension RealExports {
    /// The owner's §5.5 check, on real files: a landscape 1080p video at 9:16 comes out 606×1080 (the size Done says, never enlarged), and
    /// the captions burned in are the ones Export options picked: the original, the translation, both, or none, with the two languages in
    /// clearly different words so the pixels tell them apart. The choice reaches the export as the review sets it (`baseEditForExport`,
    /// covered in `TakeReviewViewModelTests`); here the file is read.
    @MainActor
    @Suite("Export · caption language and real size", .serialized, .timeLimit(.minutes(10)))
    struct ExportCaptionChoiceTests {
        private let recording = CGSize(width: 1920, height: 1080)
        private let expected = CGSize(width: 606, height: 1080)

        /// Export options' four answers for the captions; nil burns none in.
        private let choices: [(name: String, display: CaptionDisplay?)] = [
            ("original", .original), ("translation", .translation(.english)), ("both", .bilingual(.english)), ("off", nil),
        ]

        private func edit(showing display: CaptionDisplay?) -> TakeEdit {
            var edit = TakeEdit(sourceDuration: 2, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.showsCaptions = true
            let cue = CaptionCue(text: "Sua ideia merece vida", start: 0, end: 2)
            edit.captions = [cue]
            let line = TranslatedCaptionLine(cueIDs: [cue.id], sourceText: cue.text, text: "WHAT A BIG MOMENT", start: 0, end: 2)
            edit.captionTranslations = [CaptionTranslation(language: .english, lines: [line])]
            edit.captionDisplay = display ?? .original
            return edit
        }

        @concurrent
        private func frame(of url: URL, at time: Double) async throws -> CGImage {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            return try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
        }

        private func pixels(_ image: CGImage) throws -> [UInt8] {
            let width = Int(expected.width), height = Int(expected.height)
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let context = try #require(CGContext(
                data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(origin: .zero, size: expected))
            return bytes
        }

        private func meanDifference(_ first: [UInt8], _ second: [UInt8]) -> Double {
            Double(zip(first, second).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }) / Double(first.count)
        }

        private func uprightSize(of url: URL) async throws -> CGSize {
            let track = try #require(try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first)
            let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
            let upright = CGRect(origin: .zero, size: size).applying(transform)
            return CGSize(width: abs(upright.width), height: abs(upright.height))
        }

        @Test func eachCaptionChoiceBurnsItsOwnWordsAtTheRealSize() async throws {
            let clip = try await TestClip.make(seconds: 2, width: Int(recording.width), height: Int(recording.height))
            defer { try? FileManager.default.removeItem(at: clip) }
            // The size the app says is the size the file has.
            #expect(ExportFrameSize.size(uprightSize: recording, aspect: .portrait, shortSide: nil) == expected)
            var frames: [String: [UInt8]] = [:]
            for choice in choices {
                let output = try await VideoExportService().export(
                    videoAt: clip,
                    options: ExportOptions(aspect: .portrait, edit: edit(showing: choice.display), burnsInCaptions: choice.display != nil)
                )
                defer { try? FileManager.default.removeItem(at: output) }
                #expect(try await uprightSize(of: output) == expected, "\(choice.name)")
                let image = try await frame(of: output, at: 1)
                frames[choice.name] = try pixels(image)
                Attachment.record(try #require(UIImage(cgImage: image).pngData()), named: "caption-choice-\(choice.name).png")
            }
            let original = try #require(frames["original"]), translation = try #require(frames["translation"])
            let both = try #require(frames["both"]), off = try #require(frames["off"])
            let metrics: [(String, Double)] = [
                ("original/off", meanDifference(original, off)), ("translation/off", meanDifference(translation, off)),
                ("both/off", meanDifference(both, off)), ("original/translation", meanDifference(original, translation)),
                ("both/original", meanDifference(both, original)), ("both/translation", meanDifference(both, translation)),
            ]
            Attachment.record(metrics.map { "\($0.0): \($0.1)" }.joined(separator: "\n"), named: "caption-choice-metrics.txt")
            // Every choice with captions burns something; each one's words differ from the others'.
            for (pair, difference) in metrics { #expect(difference > 0.15, "\(pair): \(difference)") }
        }
    }
}
