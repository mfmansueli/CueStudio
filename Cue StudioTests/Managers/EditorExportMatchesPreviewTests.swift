//
//  EditorExportMatchesPreviewTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

extension RealExports {
    /// What the editor exports is what its preview shows: the same length, the same cuts (a part taken
    /// out never shows), and the same texts, captions and look at key frames.
    @MainActor
    @Suite("Editor export matches the preview", .serialized, .timeLimit(.minutes(10)))
    struct EditorExportMatchesPreviewTests {
        private let size = CGSize(width: 360, height: 640)

        @concurrent
        private func image(_ asset: AVAsset, composition: AVVideoComposition?, at time: Double) async throws -> UIImage {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.videoComposition = composition
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            return UIImage(cgImage: try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image)
        }

        private func pixels(_ image: UIImage) throws -> [UInt8] {
            let cgImage = try #require(image.cgImage)
            let width = Int(size.width), height = Int(size.height)
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let context = try #require(CGContext(
                data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
            return bytes
        }

        private func meanDifference(_ first: UIImage, _ second: UIImage) throws -> Double {
            let differences = zip(try pixels(first), try pixels(second)).map { abs(Int($0) - Int($1)) }
            return Double(differences.reduce(0, +)) / Double(differences.count)
        }

        /// RGB at a point with nothing drawn over it (the left edge, halfway down).
        private func plainColor(_ image: UIImage) throws -> [Int] {
            let bytes = try pixels(image)
            let index = (Int(size.height / 2) * Int(size.width) + 8) * 4
            return [Int(bytes[index]), Int(bytes[index + 1]), Int(bytes[index + 2])]
        }

        @Test func cutsTextsCaptionsAndLookExportAsPreviewed() async throws {
            let clip = try await TestClip.make(seconds: 4)
            defer { try? FileManager.default.removeItem(at: clip) }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            // Second 1 (green) goes.
            let removed = edit.timeline.remove([TimeSpan(start: 1, end: 2)])
            #expect(removed)
            var title = TextOverlay(role: .title, look: TypePreset.cue.look(for: .title), preset: .cue, span: TimeSpan(start: 0, end: 3))
            title.text = "5 comidas de SP"
            edit.texts = [title]
            edit.showsCaptions = true
            edit.captions = [CaptionCue(text: "Massa fina, muito recheio", start: 2.2, end: 3.6)]
            edit.contrast = 20
            let preview = try await TakeEditService().previewItem(forVideoAt: clip, edit: edit)
            let output = try await VideoExportService().export(
                videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit, burnsInCaptions: true, shortSide: 1080, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            let exported = AVURLAsset(url: output)

            let duration = try await exported.load(.duration).seconds
            #expect(abs(duration - 3) < 0.05)
            for time in [0.5, 1.5, 2.5] {
                let shown = try await image(preview.asset, composition: preview.videoComposition, at: time)
                let written = try await image(exported, composition: nil, at: time)
                let difference = try meanDifference(shown, written)
                #expect(difference < 3, "at \(time) s: \(difference)")
                Attachment.record(try #require(written.pngData()), named: "export-\(time).png")
            }
            // At 1.5 s of the edit the video is past the cut: blue (second 2), never green (second 1).
            let afterCut = try plainColor(try await image(exported, composition: nil, at: 1.5))
            #expect(afterCut[2] > afterCut[1] + 60, "\(afterCut)")
            // The title and caption are drawn: the frame isn't the plain recording.
            let original = try await image(AVURLAsset(url: clip), composition: nil, at: 0.5)
            #expect(try meanDifference(original, try await image(exported, composition: nil, at: 0.5)) > 0.5)
        }

        /// Everything new at once (`EditorMontage`): a Zoom and a Flash transition caught halfway, a frozen frame, the part of a
        /// B-roll, an arrow sliding up and Bold hook captions draw the same in the preview and the export, which is as long and
        /// has the sound effect where it was put.
        @Test func aMontageWithTheNewToolsExportsAsPreviewed() async throws {
            let take = try await TestClip.make(seconds: 6)
            let other = try await TestClip.make(seconds: 4)
            let broll = try await TestClip.make(seconds: 6)
            defer { [take, other, broll].forEach { try? FileManager.default.removeItem(at: $0) } }
            let otherName = try EditMediaFiles.link(other)
            let brollName = try EditMediaFiles.link(broll)
            let stillName = try await StillClipWriter.write(frameOf: other, at: 2.5, length: 5)
            let soundName = try EditMediaFiles.link(try SoundEffectSynth.file(for: .whoosh))
            defer { EditMediaFiles.remove([otherName, brollName, stillName, soundName]) }
            let edit = EditorMontage.edit(files: EditorMontage.Files(other: otherName, broll: brollName, still: stillName, sound: soundName))

            let preview = try await TakeEditService().previewItem(forVideoAt: take, edit: edit)
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, burnsInCaptions: true, shortSide: 1080, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            let exported = AVURLAsset(url: output)
            #expect(abs(try await exported.load(.duration).seconds - EditorMontage.duration) < 0.05)
            // Inside the arrow's slide, the Zoom (2.7–3.3 s), the frozen frame, the Flash (around 6 s) and the B-roll. On frames
            // of the 30 fps export: in between, the preview draws the exact moment and a flash changes fast.
            for frame in [12, 87, 93, 165, 178, 179, 210] {
                let time = Double(frame) / 30
                let shown = try await image(preview.asset, composition: preview.videoComposition, at: time)
                let written = try await image(exported, composition: nil, at: time)
                let difference = try meanDifference(shown, written)
                #expect(difference < 3, "at \(time) s: \(difference)")
                Attachment.record(try #require(written.pngData()), named: "montage-\(time).png")
            }
            // The whoosh plays from 2.6 s; the frozen frame has no sound of its own.
            #expect(try await TestClip.loudness(of: output, from: 2.65, to: 2.9) > -40)
        }
    }
}
