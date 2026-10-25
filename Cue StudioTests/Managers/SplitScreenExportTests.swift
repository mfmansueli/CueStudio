//
//  SplitScreenExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// The split screen through the real export: each area shows its own content, the main video reframed into its area (a
    /// two-tone take shows both of its halves there, which a support merely covering half of it never would), swapping and
    /// the ratios and side by side put each content where they say, a moment without a support has the main video on the
    /// whole frame, a cut in the speech is cut out of the support too, a photo fits without being stretched, and the two
    /// sounds are turned up and down on their own without ever playing twice.
    @MainActor
    @Suite("Split screen export", .serialized, .timeLimit(.minutes(10)))
    struct SplitScreenExportTests {
        /// The take: red over blue, 4 s. The support: green, laid from 1 to 3 s.
        private func export(
            layout: SplitLayout = SplitLayout(), supports: [TimeSpan] = [TimeSpan(start: 1, end: 3)], seconds: Int = 4,
            change: (inout TakeEdit) -> Void = { _ in }
        ) async throws -> URL {
            let take = try await TwoToneClip.make(seconds: seconds, top: TwoToneClip.red, bottom: TwoToneClip.blue)
            let support = try await TwoToneClip.make(seconds: 4, top: TwoToneClip.green, bottom: TwoToneClip.green)
            defer {
                try? FileManager.default.removeItem(at: take)
                try? FileManager.default.removeItem(at: support)
            }
            let name = try EditMediaFiles.link(support)
            defer { EditMediaFiles.remove([name]) }
            var edit = TakeEdit(sourceDuration: TimeInterval(seconds), aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.splitScreen.setLayout(layout)
            edit.media = supports.map { span in
                var media = MediaOverlay(kind: .video, fileName: name, aspect: 9.0 / 16, mediaDuration: 4, span: span)
                media.layout = .split
                media.followsCuts = true
                return media
            }
            change(&edit)
            return try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 360, frameRate: 30)
            )
        }

        private func color(_ x: CGFloat, _ y: CGFloat, at time: TimeInterval, in url: URL) async throws -> [Int] {
            try await TwoToneClip.color(at: CGPoint(x: x, y: y), time: time, in: url)
        }

        @Test func theMainVideoIsReframedInItsAreaAndHasTheWholeFrameAround() async throws {
            let output = try await export()
            defer { try? FileManager.default.removeItem(at: output) }
            // Support on top, main below, half and half.
            #expect(TwoToneClip.same(try await color(0.5, 0.25, at: 2, in: output), TwoToneClip.green))
            // The main area shows the middle of the take: its red top half just under the seam, its blue bottom half below.
            #expect(TwoToneClip.same(try await color(0.5, 0.6, at: 2, in: output), TwoToneClip.red))
            #expect(TwoToneClip.same(try await color(0.5, 0.9, at: 2, in: output), TwoToneClip.blue))
            // Before and after the support, the take on the whole frame.
            for time in [0.5, 3.5] {
                #expect(TwoToneClip.same(try await color(0.5, 0.25, at: time, in: output), TwoToneClip.red))
                #expect(TwoToneClip.same(try await color(0.5, 0.75, at: time, in: output), TwoToneClip.blue))
            }
        }

        @Test func thePreviewDrawsWhatTheExportDoes() async throws {
            // The editor's preview: the edit grown to the whole recording, played from the edit's start (`RenderPlan`).
            let take = try await TwoToneClip.make(seconds: 4, top: TwoToneClip.red, bottom: TwoToneClip.blue)
            let support = try await TwoToneClip.make(seconds: 4, top: TwoToneClip.green, bottom: TwoToneClip.green)
            defer {
                try? FileManager.default.removeItem(at: take)
                try? FileManager.default.removeItem(at: support)
            }
            let name = try EditMediaFiles.link(support)
            defer { EditMediaFiles.remove([name]) }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.timeline.trimStart(to: 0.5)
            edit.splitScreen.setLayout(SplitLayout())
            var media = MediaOverlay(kind: .video, fileName: name, aspect: 9.0 / 16, mediaDuration: 4, span: TimeSpan(start: 1, end: 3))
            media.layout = .split
            media.followsCuts = true
            edit.media = [media]
            let item = try await TakeEditService().previewItem(forVideoAt: take, edit: edit, purpose: .editorPreview(rendersCurveSound: true))
            let generator = AVAssetImageGenerator(asset: item.asset)
            generator.videoComposition = item.videoComposition
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            // 2 s of the recording: inside the support.
            let image = try await generator.image(at: CMTime(seconds: 2, preferredTimescale: 600)).image
            func color(_ x: CGFloat, _ y: CGFloat) throws -> [Int] {
                let width = image.width, height = image.height
                let context = try #require(CGContext(
                    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ))
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
                let offset = Int(y * CGFloat(height)) * width * 4 + Int(x * CGFloat(width)) * 4
                return [Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2])]
            }
            #expect(TwoToneClip.same(try color(0.5, 0.25), TwoToneClip.green))
            #expect(TwoToneClip.same(try color(0.5, 0.6), TwoToneClip.red))
            #expect(TwoToneClip.same(try color(0.5, 0.9), TwoToneClip.blue))
        }

        @Test func swappingPutsTheMainVideoOnTop() async throws {
            let output = try await export(layout: SplitLayout().swapped)
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(TwoToneClip.same(try await color(0.5, 0.1, at: 2, in: output), TwoToneClip.red))
            #expect(TwoToneClip.same(try await color(0.5, 0.4, at: 2, in: output), TwoToneClip.blue))
            #expect(TwoToneClip.same(try await color(0.5, 0.75, at: 2, in: output), TwoToneClip.green))
        }

        @Test func sixtyFortyGivesTheMainTheLargerArea() async throws {
            let output = try await export(layout: SplitLayout(ratio: .sixtyForty, larger: .main))
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(TwoToneClip.same(try await color(0.5, 0.35, at: 2, in: output), TwoToneClip.green))
            #expect(TwoToneClip.same(try await color(0.5, 0.45, at: 2, in: output), TwoToneClip.red))
            #expect(TwoToneClip.same(try await color(0.5, 0.95, at: 2, in: output), TwoToneClip.blue))
        }

        @Test func sideBySideKeepsBothWholeAcross() async throws {
            let output = try await export(layout: SplitLayout(arrangement: .sideBySide))
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(TwoToneClip.same(try await color(0.25, 0.5, at: 2, in: output), TwoToneClip.green))
            #expect(TwoToneClip.same(try await color(0.75, 0.25, at: 2, in: output), TwoToneClip.red))
            #expect(TwoToneClip.same(try await color(0.75, 0.75, at: 2, in: output), TwoToneClip.blue))
        }

        @Test func aMomentWithoutASupportHasTheMainOnTheWholeFrame() async throws {
            let output = try await export(supports: [TimeSpan(start: 0.5, end: 1.5), TimeSpan(start: 2.5, end: 3.5)])
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(TwoToneClip.same(try await color(0.5, 0.25, at: 1, in: output), TwoToneClip.green))
            #expect(TwoToneClip.same(try await color(0.5, 0.25, at: 2, in: output), TwoToneClip.red))
            #expect(TwoToneClip.same(try await color(0.5, 0.25, at: 3, in: output), TwoToneClip.green))
        }

        @Test func theSeamIsALineABlurOrAShadow() async throws {
            // The support is green, the main video's top half red: the seam at 50%.
            let line = try await export(layout: SplitLayout(seam: .line))
            defer { try? FileManager.default.removeItem(at: line) }
            #expect(try await color(0.5, 0.5, at: 2, in: line).allSatisfy { $0 > 180 })
            #expect(TwoToneClip.same(try await color(0.5, 0.52, at: 2, in: line), TwoToneClip.red))
            // Blur: just above the seam the green takes on red, just below the red takes on green; further off, untouched.
            let blur = try await export(layout: SplitLayout(seam: .blur))
            defer { try? FileManager.default.removeItem(at: blur) }
            let above = try await color(0.5, 0.495, at: 2, in: blur)
            let below = try await color(0.5, 0.505, at: 2, in: blur)
            #expect(above[0] > TwoToneClip.green[0] + 30, "above the seam: \(above)")
            #expect(below[1] > TwoToneClip.red[1] + 30, "below the seam: \(below)")
            #expect(TwoToneClip.same(try await color(0.5, 0.4, at: 2, in: blur), TwoToneClip.green))
            #expect(TwoToneClip.same(try await color(0.5, 0.6, at: 2, in: blur), TwoToneClip.red))
            // Shadow: darker on the seam, the same away from it.
            let shadow = try await export(layout: SplitLayout(seam: .shadow))
            defer { try? FileManager.default.removeItem(at: shadow) }
            let shaded = try await color(0.5, 0.505, at: 2, in: shadow)
            #expect(shaded[0] < TwoToneClip.red[0] - 50, "on the seam: \(shaded)")
            #expect(TwoToneClip.same(try await color(0.5, 0.65, at: 2, in: shadow), TwoToneClip.red))
        }

        @Test func aPhotoOfAnotherShapeFitsWithoutBeingStretched() async throws {
            let photo = try TwoToneClip.photo(color: TwoToneClip.yellow, width: 1600, height: 900)
            defer { try? FileManager.default.removeItem(at: photo) }
            let name = try EditMediaFiles.link(photo)
            defer { EditMediaFiles.remove([name]) }
            let output = try await export(supports: []) { edit in
                var media = MediaOverlay(kind: .photo, fileName: name, aspect: 16.0 / 9, mediaDuration: nil, span: TimeSpan(start: 1, end: 3))
                media.layout = .split
                media.followsCuts = true
                media.areaFraming = AreaFraming(fit: .fit)
                edit.media = [media]
            }
            defer { try? FileManager.default.removeItem(at: output) }
            // 16:9 in a 360×320 area: 360×202 in the middle, black above and below it.
            #expect(TwoToneClip.same(try await color(0.5, 0.25, at: 2, in: output), TwoToneClip.yellow))
            #expect(try await color(0.5, 0.03, at: 2, in: output).allSatisfy { $0 < 30 })
            #expect(TwoToneClip.same(try await color(0.5, 0.9, at: 2, in: output), TwoToneClip.blue))
        }

        @Test func aLandscapeVideoFillsAPortraitTakesAreaWithoutBeingStretched() async throws {
            // A 16:9 support (640×360) in the 360×320 area on top: Fill covers the area edge to edge, cropping its sides, never
            // squeezing it.
            let wide = try await TwoToneClip.make(seconds: 4, top: TwoToneClip.green, bottom: TwoToneClip.green, width: 640, height: 360)
            defer { try? FileManager.default.removeItem(at: wide) }
            let name = try EditMediaFiles.link(wide)
            defer { EditMediaFiles.remove([name]) }
            let output = try await export(supports: []) { edit in
                var media = MediaOverlay(kind: .video, fileName: name, aspect: 16.0 / 9, mediaDuration: 4, span: TimeSpan(start: 1, end: 3))
                media.layout = .split
                media.followsCuts = true
                edit.media = [media]
            }
            defer { try? FileManager.default.removeItem(at: output) }
            // Filling: the area is covered edge to edge, no bars. (A 640×360 video is read with the standard-definition color
            // matrix, so its green comes out a little lighter: green by its dominant channel.)
            for x in [0.05, 0.5, 0.95] {
                for y in [0.03, 0.25, 0.47] {
                    let found = try await color(x, y, at: 2, in: output)
                    #expect(found[1] > found[0] + 60 && found[1] > found[2] + 60, "at \(x), \(y): \(found)")
                }
            }
            #expect(TwoToneClip.same(try await color(0.5, 0.6, at: 2, in: output), TwoToneClip.red))
        }

        @Test func aStretchCutFromTheSpeechIsCutFromTheSupport() async throws {
            // The take and the support show a color per second; 3 to 5 s of the take are cut, under a support laid from 1 s.
            let take = try await TestClip.make(seconds: 8)
            let support = try await TestClip.make(seconds: 8)
            defer {
                try? FileManager.default.removeItem(at: take)
                try? FileManager.default.removeItem(at: support)
            }
            let name = try EditMediaFiles.link(support)
            defer { EditMediaFiles.remove([name]) }
            var edit = TakeEdit(sourceDuration: 8, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.timeline = EditTimeline(sourceDuration: 8, keeping: [TimeSpan(start: 0, end: 3), TimeSpan(start: 5, end: 8)])
            var media = MediaOverlay(kind: .video, fileName: name, aspect: 9.0 / 16, mediaDuration: 8, span: TimeSpan(start: 1, end: 7))
            media.layout = .split
            media.followsCuts = true
            edit.media = [media]
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 360, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            // 3.5 s of the edit is 5.5 s of the take: the support shows its second 4 (laid at 1 s), not its second 2.
            let supportColor = try await color(0.5, 0.25, at: 3.5, in: output)
            let mainColor = try await color(0.5, 0.75, at: 3.5, in: output)
            #expect(TwoToneClip.same(supportColor, TestClip.colors[4]))
            #expect(TwoToneClip.same(mainColor, TestClip.colors[5]))
        }

        @Test func eachSoundIsTurnedUpAndDownOnItsOwnAndNeverPlaysTwice() async throws {
            let take = try await TwoToneClip.make(seconds: 4, top: TwoToneClip.red, bottom: TwoToneClip.blue, loud: true)
            let support = try await TwoToneClip.make(seconds: 4, top: TwoToneClip.green, bottom: TwoToneClip.green, loud: true)
            defer {
                try? FileManager.default.removeItem(at: take)
                try? FileManager.default.removeItem(at: support)
            }
            let name = try EditMediaFiles.link(support)
            defer { EditMediaFiles.remove([name]) }
            func render(layout: MediaLayout = .split, _ change: (inout MediaOverlay) -> Void, mutesAll: Bool = false) async throws -> URL {
                var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
                edit.voiceEnhancement = .off
                edit.splitScreen.mutesMedia = mutesAll
                var media = MediaOverlay(kind: .video, fileName: name, aspect: 9.0 / 16, mediaDuration: 4, span: TimeSpan(start: 1, end: 3))
                media.layout = layout
                media.followsCuts = true
                change(&media)
                edit.media = [media]
                return try await VideoExportService(sounds: RecordingSoundCache()).export(
                    videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 360, frameRate: 30)
                )
            }
            // Added as it is: the main video heard, the support silent; the same in the split and around it.
            let muted = try await render { _ in }
            let outside = try await TestClip.loudness(of: muted, from: 0.2, to: 0.8)
            let inside = try await TestClip.loudness(of: muted, from: 1.5, to: 2.5)
            #expect(outside > -30)
            #expect(abs(inside - outside) < 1.5)
            // The same media as a window: the main video sounds exactly the same (one sound, whatever the layout).
            let window = try await render(layout: .window) { _ in }
            #expect(abs(try await TestClip.loudness(of: window, from: 1.5, to: 2.5) - inside) < 0.5)
            // Only the support: the main video silent while it shows, back after.
            let onlySupport = try await render { $0.mainVolume = 0; $0.audioVolume = 1 }
            #expect(try await TestClip.loudness(of: onlySupport, from: 1.5, to: 2.5) > -30)
            let silentMain = try await render { $0.mainVolume = 0 }
            #expect(try await TestClip.loudness(of: silentMain, from: 1.5, to: 2.5) < -50)
            #expect(try await TestClip.loudness(of: silentMain, from: 3.3, to: 3.8) > -30)
            // "Mute all supports" silences it even turned up.
            let mutedAll = try await render({ $0.mainVolume = 0; $0.audioVolume = 1 }, mutesAll: true)
            #expect(try await TestClip.loudness(of: mutedAll, from: 1.5, to: 2.5) < -50)
            for url in [muted, window, onlySupport, silentMain, mutedAll] { try? FileManager.default.removeItem(at: url) }
        }
    }
}
