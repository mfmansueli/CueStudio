//
//  CaptionMarginsByFormatExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// A TikTok take turned to 1:1 in Format: the captions take the square's margins, so a line at the bottom sits where the
    /// square puts it in the preview and in the file, not 25% up as the 9:16 margins put it (owner, 07/11/2026).
    @MainActor
    @Suite("Caption margins follow Format", .serialized, .timeLimit(.minutes(10)))
    struct CaptionMarginsByFormatExportTests {
        /// The lowest row (a fraction of the frame from the top) where something not the blue take shows: the caption's bottom.
        private func captionBottom(of image: CGImage) throws -> Double {
            let width = image.width, height = image.height
            let context = try #require(CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
            var lowest = 0
            for row in 0..<height {
                for column in stride(from: 0, to: width, by: 2) {
                    let offset = row * width * 4 + column * 4
                    if !TwoToneClip.same([Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2])], TwoToneClip.blue) {
                        lowest = row
                        break
                    }
                }
            }
            return Double(lowest) / Double(height)
        }

        @concurrent
        private static func frame(_ asset: AVAsset, composition: AVVideoComposition?, at seconds: Double) async throws -> CGImage {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.videoComposition = composition
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            return try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        }

        @Test func aSquareVideosCaptionsSitAtTheSquaresBottomInThePreviewAndTheFile() async throws {
            // The editor turns the take to 1:1, as Format does.
            let take = TestData.take(scriptID: nil, number: 1)
            let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
            takes.load()
            let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
            library.load()
            let editor = FakeTakeEditor()
            editor.duration = 3
            let viewModel = QuickEditViewModel(
                take: takes.takes[0], takes: takes, library: library, editing: editor,
                drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
                mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
            )
            await viewModel.prepare()
            let portrait = CaptionSafeArea.margins(for: take, aspect: .portrait)
            #expect(viewModel.edit.captionCollection?.safeMargins == portrait)
            viewModel.look.setAspect(.square)
            var edit = viewModel.edit
            #expect(edit.captionCollection?.safeMargins == CaptionSafeArea.margins(for: take, aspect: .square))
            edit.voiceEnhancement = .off
            edit.showsCaptions = true
            edit.captions = [CaptionCue(text: "Massa fina", start: 0.2, end: 2.8)]

            let video = try await TwoToneClip.make(seconds: 3, top: TwoToneClip.blue, bottom: TwoToneClip.blue)
            defer { try? FileManager.default.removeItem(at: video) }
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: video, options: ExportOptions(aspect: .square, edit: edit, burnsInCaptions: true, shortSide: 360, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            let file = try captionBottom(of: try await Self.frame(AVURLAsset(url: output), composition: nil, at: 1.5))
            let item = try await TakeEditService().previewItem(forVideoAt: video, edit: edit, purpose: .editorPreview(rendersCurveSound: true))
            let preview = try captionBottom(of: try await Self.frame(item.asset, composition: item.videoComposition, at: 1.5))
            // The 9:16 margins end the safe area 25% from the bottom; the square's, 7%. A line placed at 76% reaches past 76%.
            #expect(file > 0.77, "the file's caption ends at \(file)")
            #expect(file < 0.93, "the file's caption ends at \(file)")
            #expect(abs(preview - file) < 0.02, "preview \(preview), file \(file)")
        }
    }
}
