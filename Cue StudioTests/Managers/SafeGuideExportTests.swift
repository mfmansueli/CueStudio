//
//  SafeGuideExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// The editor's safe zone guide in real files (owner, decision B, 07/11/2026): "the guide stays in the editor" (no line, no shade
    /// in the file or in the composition the preview plays, with the guide on) and "the captions' place in the file matches the
    /// preview" for the guide picked (a line at the bottom keeps to Stories' clear area, lower than TikTok's, in both alike).
    @MainActor
    @Suite("Safe zone guide in the file", .serialized, .timeLimit(.minutes(10)))
    struct SafeGuideExportTests {
        /// A frame's pixels, four bytes each (RGBA), row by row from the top.
        private func pixels(of image: CGImage) throws -> (width: Int, height: Int, bytes: [UInt8]) {
            let width = image.width, height = image.height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            try bytes.withUnsafeMutableBytes { buffer in
                let context = try #require(CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ))
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            return (width, height, bytes)
        }

        private func isTake(_ frame: (width: Int, height: Int, bytes: [UInt8]), column: Int, row: Int) -> Bool {
            let offset = row * frame.width * 4 + column * 4
            return TwoToneClip.same([Int(frame.bytes[offset]), Int(frame.bytes[offset + 1]), Int(frame.bytes[offset + 2])], TwoToneClip.blue)
        }

        /// The lowest row (a fraction of the frame from the top) where something not the blue take shows: the caption's bottom.
        private func captionBottom(of image: CGImage) throws -> Double {
            let frame = try pixels(of: image)
            var lowest = 0
            for row in 0..<frame.height {
                for column in stride(from: 0, to: frame.width, by: 2) where !isTake(frame, column: column, row: row) {
                    lowest = row
                    break
                }
            }
            return Double(lowest) / Double(frame.height)
        }

        /// How many pixels aren't the blue take, every second one of every second row.
        private func marks(in image: CGImage) throws -> Int {
            let frame = try pixels(of: image)
            var found = 0
            for row in stride(from: 0, to: frame.height, by: 2) {
                for column in stride(from: 0, to: frame.width, by: 2) where !isTake(frame, column: column, row: row) {
                    found += 1
                }
            }
            return found
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

        /// The editor on a TikTok take, the guide on: what the creator would export.
        private func editor(preferences: FakeEditorPreferencesStore) async -> QuickEditViewModel {
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
                mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(), editorPreferences: preferences
            )
            await viewModel.prepare()
            viewModel.look.setShowsSafeGuide(true)
            return viewModel
        }

        /// The file and the preview's composition at 1.5 s.
        private func file(of edit: TakeEdit, video: URL) async throws -> (file: CGImage, preview: CGImage) {
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: video, options: ExportOptions(aspect: edit.aspect, edit: edit, burnsInCaptions: true, shortSide: 360, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            let file = try await Self.frame(AVURLAsset(url: output), composition: nil, at: 1.5)
            let item = try await TakeEditService().previewItem(forVideoAt: video, edit: edit, purpose: .editorPreview(rendersCurveSound: true))
            let preview = try await Self.frame(item.asset, composition: item.videoComposition, at: 1.5)
            return (file, preview)
        }

        @Test func theGuideIsNeverDrawnInTheFileNorInThePreviewsVideo() async throws {
            let preferences = FakeEditorPreferencesStore()
            let viewModel = await editor(preferences: preferences)
            viewModel.look.pickSafeGuide(.platform(.reels))
            #expect(preferences.showsSafeGuide && viewModel.showsSafeGuideOverlay)
            var edit = viewModel.edit
            edit.voiceEnhancement = .off
            #expect(edit.safeGuide == .platform(.reels))

            let video = try await TwoToneClip.make(seconds: 3, top: TwoToneClip.blue, bottom: TwoToneClip.blue)
            defer { try? FileManager.default.removeItem(at: video) }
            let frames = try await file(of: edit, video: video)
            // The guide's white line, its halo and the shade over the covered zones would each leave pixels that aren't blue.
            #expect(try marks(in: frames.file) == 0, "the file has something over the take")
            #expect(try marks(in: frames.preview) == 0, "the preview's video has something over the take")
        }

        @Test func aLineAtTheBottomKeepsToThePickedAppsClearAreaInThePreviewAndTheFile() async throws {
            let viewModel = await editor(preferences: FakeEditorPreferencesStore())
            let video = try await TwoToneClip.make(seconds: 3, top: TwoToneClip.blue, bottom: TwoToneClip.blue)
            defer { try? FileManager.default.removeItem(at: video) }

            var bottoms: [SafeGuideChoice: Double] = [:]
            for choice in [SafeGuideChoice.platform(.tiktok), .platform(.stories)] {
                viewModel.look.pickSafeGuide(choice)
                var edit = viewModel.edit
                #expect(edit.captionCollection?.safeMargins == CaptionSafeArea.zones.margins(of: choice, aspect: .portrait))
                edit.voiceEnhancement = .off
                edit.showsCaptions = true
                edit.captions = [CaptionCue(text: "Massa fina", start: 0.2, end: 2.8)]
                let frames = try await file(of: edit, video: video)
                let file = try captionBottom(of: frames.file)
                let preview = try captionBottom(of: frames.preview)
                #expect(abs(preview - file) < 0.02, "\(choice.key): preview \(preview), file \(file)")
                // Never past the guide's clear area.
                let clear = CaptionSafeArea.zones.margins(of: choice, aspect: .portrait).unitContentRect.maxY
                #expect(file <= clear + 0.01, "\(choice.key): the line ends at \(file), the clear area at \(clear)")
                bottoms[choice] = file
            }
            // TikTok's buttons cover 25% of the bottom, Stories' 13%: the line sits lower with Stories.
            let tiktok = try #require(bottoms[.platform(.tiktok)]), stories = try #require(bottoms[.platform(.stories)])
            #expect(stories > tiktok + 0.03, "Stories \(stories), TikTok \(tiktok)")
        }
    }
}
