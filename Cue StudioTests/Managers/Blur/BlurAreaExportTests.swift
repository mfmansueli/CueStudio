//
//  BlurAreaExportTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// Blur areas and masks in the exported file, on a red-over-blue take: a yellow bar where the area is, and only there; still
    /// on the same part of the recording after Format crops it, a speed change and a cut; inside the main area of a split
    /// screen; on a video laid over the take (and not on the take under it); and a circle mask showing a green video inside it,
    /// the take around it.
    @MainActor
    @Suite("Blur area and mask export", .serialized, .timeLimit(.minutes(10)))
    struct BlurAreaExportTests {
        /// A yellow bar over the recording's (0.4–0.6, 0.35–0.45): in the red half.
        private func bar(_ span: TimeSpan = TimeSpan(start: 0, end: 4), on target: BlurTarget = .recording(nil)) -> BlurRegion {
            var region = BlurRegion(target: target, span: span, box: NormalizedBox(x: 0.4, y: 0.35, width: 0.2, height: 0.1))
            region.style = .solid
            region.color = .yellow
            return region
        }

        private func export(_ change: (inout TakeEdit, _ media: String) -> Void) async throws -> URL {
            let take = try await TwoToneClip.make(seconds: 4, top: TwoToneClip.red, bottom: TwoToneClip.blue)
            let green = try await TwoToneClip.make(seconds: 4, top: TwoToneClip.green, bottom: TwoToneClip.green)
            defer {
                try? FileManager.default.removeItem(at: take)
                try? FileManager.default.removeItem(at: green)
            }
            let name = try EditMediaFiles.link(green)
            defer { EditMediaFiles.remove([name]) }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            change(&edit, name)
            return try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: edit.aspect, edit: edit, shortSide: 360, frameRate: 30)
            )
        }

        private func color(_ point: CGPoint, at time: TimeInterval, in url: URL) async throws -> [Int] {
            try await TwoToneClip.color(at: point, time: time, in: url)
        }

        @Test func theBarIsWhereTheAreaIsAndNowhereElse() async throws {
            let output = try await export { edit, _ in edit.blurRegions = [bar()] }
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.5, y: 0.4), at: 1, in: output), TwoToneClip.yellow))
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.5, y: 0.2), at: 1, in: output), TwoToneClip.red))
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.2, y: 0.4), at: 1, in: output), TwoToneClip.red))
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.5, y: 0.8), at: 1, in: output), TwoToneClip.blue))
        }

        @Test func itStaysOnTheRecordingThroughACropASpeedChangeAndACut() async throws {
            let output = try await export { edit, _ in
                // Recording 1–3 s covered; cut 0.5–1 s out, the rest at 2×; a square crop.
                edit.blurRegions = [bar(TimeSpan(start: 1, end: 3))]
                _ = edit.timeline.removeEdited(0.5...1)
                _ = edit.timeline.setSpeed(2, forSegmentAt: edit.timeline.segments.count - 1)
                edit.aspect = .square
            }
            defer { try? FileManager.default.removeItem(at: output) }
            // The square crop keeps the recording's y 140–500 (of 640): its y 0.4 lands at (256 − 140) / 360 = 0.32.
            let spot = CGPoint(x: 0.5, y: (0.4 * 640 - 140) / 360)
            // Edited 0.5 s is the recording's 1.0 s, and 1.25 s its 2.5 s: covered. Edited 1.5 s is its 3.0 s on: not.
            #expect(TwoToneClip.same(try await color(spot, at: 0.6, in: output), TwoToneClip.yellow))
            #expect(TwoToneClip.same(try await color(spot, at: 1.2, in: output), TwoToneClip.yellow))
            #expect(TwoToneClip.same(try await color(spot, at: 1.6, in: output), TwoToneClip.red))
            #expect(TwoToneClip.same(try await color(spot, at: 0.3, in: output), TwoToneClip.red))
        }

        @Test func inTheSplitScreenItIsInTheMainArea() async throws {
            let output = try await export { edit, name in
                edit.blurRegions = [bar()]
                edit.splitScreen.setLayout(SplitLayout())
                var support = MediaOverlay(kind: .video, fileName: name, aspect: 9.0 / 16, mediaDuration: 4, span: TimeSpan(start: 1, end: 3))
                support.layout = .split
                support.followsCuts = true
                edit.media = [support]
            }
            defer { try? FileManager.default.removeItem(at: output) }
            // Support on top; the take fills the bottom half centered: the recording's y 0.4 is at 0.5 + (0.4 × 640 − 160) / 640.
            let inArea = CGPoint(x: 0.5, y: 0.5 + (0.4 * 640 - 160) / 640)
            #expect(TwoToneClip.same(try await color(inArea, at: 2, in: output), TwoToneClip.yellow))
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.5, y: 0.25), at: 2, in: output), TwoToneClip.green))
            // Without the support, back on the whole frame where the recording has it.
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.5, y: 0.4), at: 0.5, in: output), TwoToneClip.yellow))
        }

        @Test func anAreaOnAVideoOverTheTakeIsOnThatVideoOnly() async throws {
            let output = try await export { edit, name in
                var window = MediaOverlay(kind: .video, fileName: name, aspect: 9.0 / 16, mediaDuration: 4, span: TimeSpan(start: 1, end: 3))
                window.layout = .fullFrame
                window.followsCuts = true
                edit.media = [window]
                edit.blurRegions = [bar(on: .media(window.id))]
            }
            defer { try? FileManager.default.removeItem(at: output) }
            // Over the green video while it shows; the take under it, before, has no bar.
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.5, y: 0.4), at: 1.5, in: output), TwoToneClip.yellow))
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.5, y: 0.2), at: 1.5, in: output), TwoToneClip.green))
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.5, y: 0.4), at: 0.5, in: output), TwoToneClip.red))
        }

        @Test func aCircleMaskShowsTheVideoInsideAndTheTakeAround() async throws {
            let output = try await export { edit, name in
                var window = MediaOverlay(kind: .video, fileName: name, aspect: 9.0 / 16, mediaDuration: 4, span: TimeSpan(start: 0, end: 4))
                window.layout = .fullFrame
                window.followsCuts = true
                window.mask = MediaMask(shape: .circle, placement: MaskPlacement(center: OverlayPoint(x: 0.5, y: 0.25), width: 0.5, height: 0.5 * 9 / 16))
                edit.media = [window]
            }
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.5, y: 0.25), at: 1, in: output), TwoToneClip.green))
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.1, y: 0.25), at: 1, in: output), TwoToneClip.red), "outside the circle, the take")
            #expect(TwoToneClip.same(try await color(CGPoint(x: 0.5, y: 0.75), at: 1, in: output), TwoToneClip.blue))
        }
    }
}
