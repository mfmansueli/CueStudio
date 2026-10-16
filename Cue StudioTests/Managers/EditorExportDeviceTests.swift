//
//  EditorExportDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// How long the editor's export takes on this device for the montage with everything new (`EditorMontage`: two transitions,
/// a frozen frame, a B-roll part, an animated arrow, Bold hook captions burned in, a sound effect) over footage that decodes
/// like a recording, with Studio Voice on and the take's background blurred, at 1080p and 4K; and how long one frame of each
/// transition takes to draw at those sizes. Printed as `EDITOR EXPORT …` and `TRANSITION FRAME …`.
///
/// Opt-in and on a device: `CUE_DEVICE="<iPhone>" scripts/test.sh device EditorExportDeviceTests`.
@MainActor
@Suite(
    "Editor export on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_EDITOR_EXPORT"] != nil)
)
struct EditorExportDeviceTests {
    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    @Test(arguments: [1080, 2160])
    func theMontageExports(shortSide: Int) async throws {
        let width = shortSide, height = shortSide * 16 / 9
        let take = try await TestFootage.make(seconds: 6, width: width, height: height)
        let other = try await TestFootage.make(seconds: 4, width: width, height: height)
        let broll = try await TestFootage.make(seconds: 6, width: width, height: height)
        defer { [take, other, broll].forEach { try? FileManager.default.removeItem(at: $0) } }
        let otherName = try EditMediaFiles.link(other)
        let brollName = try EditMediaFiles.link(broll)
        let freezing = uptime
        let stillName = try await StillClipWriter.write(frameOf: other, at: 2.5, length: 5)
        let froze = uptime - freezing
        let soundName = try EditMediaFiles.link(try SoundEffectSynth.file(for: .whoosh))
        defer { EditMediaFiles.remove([otherName, brollName, stillName, soundName]) }
        var edit = EditorMontage.edit(files: EditorMontage.Files(other: otherName, broll: brollName, still: stillName, sound: soundName))
        edit.voiceEnhancement = .soft
        var blur = BackgroundEffect()
        blur.style = .blur
        edit.backgrounds = [RecordingBackground(sourceID: nil, effect: blur)]

        let started = uptime
        let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
            videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: CGFloat(shortSide), frameRate: 30)
        )
        let took = uptime - started
        defer { try? FileManager.default.removeItem(at: output) }
        let duration = try await AVURLAsset(url: output).load(.duration).seconds
        let size = (try? FileManager.default.attributesOfItem(atPath: output.path(percentEncoded: false))[.size] as? Int) ?? 0
        print(
            "EDITOR EXPORT \(shortSide == 1080 ? "1080p" : "4K") · \(String(format: "%.1f", duration)) s of video"
                + " · export \(String(format: "%.1f", took)) s (\(String(format: "%.2f", took / duration))× its length)"
                + " · freeze frame \(String(format: "%.2f", froze)) s · \(size / 1_000_000) MB"
        )
        #expect(abs(duration - EditorMontage.duration) < 0.1)
    }

    @Test(arguments: [1080, 2160])
    func eachTransitionDrawsAFrameInTime(shortSide: Int) throws {
        let extent = CGRect(x: 0, y: 0, width: shortSide, height: shortSide * 16 / 9)
        let from = CIImage(color: CIColor(red: 0.8, green: 0.5, blue: 0.3)).cropped(to: extent)
            .applyingFilter("CIRandomGenerator").cropped(to: extent)
        let to = CIImage(color: CIColor(red: 0.1, green: 0.2, blue: 0.7)).cropped(to: extent)
        let context = CIContext(options: [.cacheIntermediates: false])
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(extent.width), Int(extent.height), kCVPixelFormatType_32BGRA, nil, &buffer)
        let target = try #require(buffer)
        for transition in [EditTransition.dissolve, .zoom, .blur, .flash, .push, .punch, .wipe] {
            var times: [TimeInterval] = []
            for step in 0..<20 {
                let image = TransitionDrawing.draw(transition, from: from, to: to, progress: Double(step) / 19)
                let started = uptime
                context.render(image, to: target)
                times.append(uptime - started)
            }
            let sorted = times.dropFirst().sorted()
            let median = sorted[sorted.count / 2], worst = sorted.last ?? 0
            print(
                "TRANSITION FRAME \(transition.rawValue) · \(shortSide == 1080 ? "1080p" : "4K")"
                    + " · p50 \(Int((median * 1000).rounded())) ms · max \(Int((worst * 1000).rounded())) ms"
            )
        }
    }
}
