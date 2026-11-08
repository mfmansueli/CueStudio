//
//  SkinSmoothingDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import os
import Testing
import UIKit
@testable import Cue_Studio

/// Skin on a real face, with the real Vision detector, on this device: how much each step of Smooth takes off the skin (and today's top against the
/// first engine's), how long a frame takes at 1080p and 4K with every control at its top, whether it holds steady while the face moves, whether the
/// preview and the export match, and what an export costs in time and memory. Needs a portrait photo with a face (it is moved and zoomed into a
/// video: there is no footage of people in the repository); the results are printed as `SKIN SMOOTHING …` lines.
///
/// Opt-in: `TEST_RUNNER_CUE_SKIN_E2E=1 TEST_RUNNER_CUE_SKIN_MEDIA=<photo> xcodebuild … -only-testing:"Cue StudioTests/SkinSmoothingDeviceTests" test`.
/// On a device the photo is a file in the app's Documents folder (`xcrun devicectl device copy to … --domain-type appDataContainer
/// --domain-identifier <bundle id> --destination Documents/skin.jpg`), given as a path relative to it (`Documents/skin.jpg`).
@MainActor
@Suite(
    "Skin Smoothing on a real face",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_SKIN_E2E"] != nil),
    .timeLimit(.minutes(30))
)
struct SkinSmoothingDeviceTests {
    enum Resolution: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case hd = "1080p", uhd = "4K"

        var size: CGSize { self == .hd ? CGSize(width: 1080, height: 1920) : CGSize(width: 2160, height: 3840) }
        var testDescription: String { rawValue }
    }

    private static let frames = 90

    /// Every control of Skin at its top: the heaviest a frame gets.
    private static let top = SkinLook(smoothing: SkinSmoothing(amount: 100), faceLight: 100, antiShine: 100)

    private func photo() throws -> CIImage {
        let path = try #require(ProcessInfo.processInfo.environment["CUE_SKIN_MEDIA"], "CUE_SKIN_MEDIA names the photo")
        let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : URL.homeDirectory.appending(path: path)
        return try #require(CIImage(contentsOf: url, options: [.applyOrientationProperty: true]), "no photo at \(url.path)")
    }

    /// The photo, whole, about two thirds of the frame's width (a face as a selfie has it: all of it in the shot), over a blurred copy of itself, drifting
    /// and zooming a little more with every frame, like a creator who moves.
    private func frame(_ index: Int, of photo: CIImage, size: CGSize) -> CIImage {
        let progress = CGFloat(index) / CGFloat(Self.frames)
        let centered = photo.transformed(by: CGAffineTransform(translationX: -photo.extent.minX - photo.extent.midX, y: -photo.extent.minY - photo.extent.midY))
        func place(_ scale: CGFloat, dx: CGFloat = 0) -> CIImage {
            centered.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: size.width / 2 + dx, y: size.height / 2))
        }
        let bounds = CGRect(origin: .zero, size: size)
        let cover = max(size.width / photo.extent.width, size.height / photo.extent.height)
        let background = place(cover).clampedToExtent().applyingGaussianBlur(sigma: 40 * size.width / 1080).cropped(to: bounds)
        let width = size.width * (0.62 + 0.08 * progress) / photo.extent.width
        return place(width, dx: 40 * sin(progress * 2 * .pi) * (size.width / 1080)).composited(over: background).cropped(to: bounds)
    }

    /// A result: printed, and kept with the test (a device's console isn't where `xcodebuild` shows a test's output).
    private func note(_ line: String) {
        print(line)
        Attachment.record(line, named: "SKIN SMOOTHING \(abs(line.hashValue)).txt")
    }

    private func percentile(_ values: [Double], _ share: Double) -> Double {
        let sorted = values.sorted()
        return sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * share))]
    }

    private func report(_ values: [Double]) -> String {
        String(format: "p50 %.1f ms · p95 %.1f ms · max %.1f ms", percentile(values, 0.5), percentile(values, 0.95), values.max() ?? 0)
    }

    @Test func visionFindsTheFaceInThePhotoAndInTheFrame() throws {
        let source = try photo()
        let direct = VisionFaceDetector().faces(in: source.transformed(by: CGAffineTransform(translationX: -source.extent.minX, y: -source.extent.minY)))
        note("SKIN SMOOTHING photo \(source.extent) · faces in the photo \(direct.count)")
        #expect(direct.count == 1, "Vision finds the face in the photo itself")
        let size = Resolution.hd.size
        let inFrame = VisionFaceDetector().faces(in: frame(0, of: source, size: size))
        note("SKIN SMOOTHING faces in the first 1080p frame \(inFrame.count) \(inFrame.map(\.box))")
        #expect(inFrame.count == 1, "…and in the frame the video is made of")
    }

    /// Smooth's steps on the real face (0, 25, 50, 75 and 100 on today's engine, Texture as it starts) and the first engine at 100: the detail left
    /// on the skin, in two bands (the grain, |picture − blur 0.4%|, and the spots and unevenness, |blur 0.4% − blur 3%|, in fractions of the face's
    /// width), under the skin mask, relative to the picture's own. Each step takes more, and today's top takes more of the spots than the first's.
    @Test func eachStepSmoothsMoreAndTodaysTopGoesFurtherThanTheFirst() throws {
        let source = try photo()
        let image = frame(0, of: source, size: Resolution.hd.size)
        let context = CIContext(options: [.cacheIntermediates: false])
        let pass = SkinSmoother(context: context).pass(for: image, stream: .main, epoch: 0, time: 0)
        let face = try #require(pass.faces.first, "Vision finds the face")
        let region = face.region
        let mask = face.mask.cropped(to: region)
        func mean(_ picture: CIImage) -> Double {
            var pixel = [Float](repeating: 0, count: 4)
            let average = picture.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: region)])
            context.render(average, toBitmap: &pixel, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
            return Double(pixel[0] + pixel[1] + pixel[2]) / 3
        }
        func blurred(_ picture: CIImage, _ share: Double) -> CIImage {
            picture.clampedToExtent().applyingGaussianBlur(sigma: max(1, face.width * share)).cropped(to: region)
        }
        func band(_ first: CIImage, _ second: CIImage) -> Double {
            let difference = first.applyingFilter("CIDifferenceBlendMode", parameters: [kCIInputBackgroundImageKey: second])
            return mean(difference.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: mask])) / max(mean(mask), 0.000_1)
        }
        func detail(_ skin: SkinLook) -> (grain: Double, spots: Double) {
            let picture = pass.apply(skin, to: image).cropped(to: region)
            let fine = blurred(picture, 0.004)
            return (band(picture, fine), band(fine, blurred(picture, 0.03)))
        }
        let steps = [0.0, 25, 50, 75, 100].map { detail(.smoothing($0)) }
        let first = detail(.firstEngine(100))
        let base = steps[0]
        func percent(_ value: Double, of whole: Double) -> String { String(format: "%.0f", value / max(whole, 0.000_001) * 100) }
        note(
            "SKIN SMOOTHING detail left on the skin, grain / spots % · today 0, 25, 50, 75, 100: "
                + steps.map { percent($0.grain, of: base.grain) + "/" + percent($0.spots, of: base.spots) }.joined(separator: " · ")
                + " · first engine at 100: " + percent(first.grain, of: base.grain) + "/" + percent(first.spots, of: base.spots)
        )
        #expect(zip(steps, steps.dropFirst()).allSatisfy { $1.spots < $0.spots }, "each step takes more of the spots")
        #expect(steps[4].spots < first.spots * 0.9, "today's top goes clearly further than the first engine's")
    }

    @Test(arguments: Resolution.allCases)
    func aFrameCostsLittleAndTheSmoothingHoldsSteady(_ resolution: Resolution) throws {
        let source = try photo()
        let context = CIContext(options: [.cacheIntermediates: false])
        let smoother = SkinSmoother(context: context)
        var look = LookSettings()
        look.skin = Self.top
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(resolution.size.width), Int(resolution.size.height), kCVPixelFormatType_32BGRA, nil, &buffer)
        let target = try #require(buffer)
        var smoothed: [Double] = [], baseline: [Double] = []
        var faces: [Int] = [], regions: [CGFloat] = [], presences: [Double] = []
        for index in 0..<Self.frames {
            let image = frame(index, of: source, size: resolution.size)
            // Without the smoothing: what a frame costs anyway.
            var started = ProcessInfo.processInfo.systemUptime
            context.render(FrameLook.apply(LookSettings(), to: image), to: target)
            baseline.append((ProcessInfo.processInfo.systemUptime - started) * 1000)
            // With it: finding the face (when it is time), and the picture drawn.
            started = ProcessInfo.processInfo.systemUptime
            let pass = smoother.pass(for: image, stream: .main, epoch: 0, time: Double(index) / 30)
            context.render(FrameLook.apply(look, to: image, skin: pass), to: target)
            smoothed.append((ProcessInfo.processInfo.systemUptime - started) * 1000)
            faces.append(pass.faces.count)
            if let face = pass.faces.first {
                regions.append(face.region.minX / resolution.size.width)
                presences.append(face.presence)
            }
        }
        // The first frames pay for loading Vision's models and compiling the filters, once.
        let warm = Array(smoothed.dropFirst(5)), warmBaseline = Array(baseline.dropFirst(5))
        note(
            "SKIN SMOOTHING \(resolution.rawValue) · faces \(faces.min() ?? 0)–\(faces.max() ?? 0) · frame with every control at 100 \(report(warm))"
                + " · without \(report(warmBaseline))"
        )
        #expect(faces.min() ?? 0 >= 1, "the face is found in every frame")
        // Steady: the face is there in full all the time and its region never jumps by more than a few percent of the frame in one frame.
        #expect(presences.allSatisfy { $0 == 1 })
        let jumps = zip(regions, regions.dropFirst()).map { abs($1 - $0) }
        note("SKIN SMOOTHING \(resolution.rawValue) · greatest step of the face's region \(String(format: "%.2f", (jumps.max() ?? 0) * 100)) % of the width")
        #expect((jumps.max() ?? 0) < 0.04)
    }

    /// Where the time of a frame goes: Vision finding the face, the face prepared (mask, tone, noise: Vision left out; here every frame is a
    /// detection, so the tone is measured on each), and the picture drawn without Skin and with each look: the first engine at 100, today's Smooth at
    /// 100 alone, Studio, every control at 100. Each at 1080p and 4K, p50 and p95 over the frames.
    @Test(arguments: Resolution.allCases)
    func whereTheTimeOfAFrameGoes(_ resolution: Resolution) throws {
        let source = try photo()
        let context = CIContext(options: [.cacheIntermediates: false])
        let detector = VisionFaceDetector()
        let looks: [(name: String, skin: SkinLook)] = [
            ("first engine at 100", .firstEngine(100)), ("Smooth at 100", .smoothing(100)), ("Face light at 100", SkinLook(faceLight: 100)),
            ("Anti-shine at 100", SkinLook(antiShine: 100)), ("Studio", SkinPreset.studio.look), ("every control at 100", Self.top),
        ]
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(resolution.size.width), Int(resolution.size.height), kCVPixelFormatType_32BGRA, nil, &buffer)
        let target = try #require(buffer)
        var found: [Double] = [], prepared: [Double] = [], plain: [Double] = []
        var drawn = Array(repeating: [Double](), count: looks.count)
        var smoother: SkinSmoother?
        for index in 0..<45 {
            let image = frame(index, of: source, size: resolution.size)
            var started = ProcessInfo.processInfo.systemUptime
            let faces = detector.faces(in: image)
            found.append((ProcessInfo.processInfo.systemUptime - started) * 1000)
            if smoother == nil { smoother = SkinSmoother(context: context, detector: FakeFaceDetector(faces: faces)) }
            started = ProcessInfo.processInfo.systemUptime
            let pass = smoother?.pass(for: image, stream: .main, epoch: 0, time: Double(index) / 30) ?? .none
            prepared.append((ProcessInfo.processInfo.systemUptime - started) * 1000)
            for (index, entry) in looks.enumerated() {
                var look = LookSettings()
                look.skin = entry.skin
                started = ProcessInfo.processInfo.systemUptime
                context.render(FrameLook.apply(look, to: image, skin: pass), to: target)
                drawn[index].append((ProcessInfo.processInfo.systemUptime - started) * 1000)
            }
            started = ProcessInfo.processInfo.systemUptime
            context.render(FrameLook.apply(LookSettings(), to: image), to: target)
            plain.append((ProcessInfo.processInfo.systemUptime - started) * 1000)
        }
        let warm = { (values: [Double]) in Array(values.dropFirst(5)) }
        note(
            "SKIN SMOOTHING \(resolution.rawValue) breakdown · Vision \(report(warm(found))) · face prepared (no Vision) \(report(warm(prepared)))"
                + " · drawn without \(report(warm(plain)))"
                + looks.indices.map { " · drawn with \(looks[$0].name) \(report(warm(drawn[$0])))" }.joined()
        )
    }

    @Test func thePreviewAndTheExportMatchWithTheRealDetector() async throws {
        let source = try photo()
        let size = Resolution.hd.size
        let clip = try await SkinTestClip.make(seconds: 3, width: Int(size.width), height: Int(size.height)) { index in
            frame(index, of: source, size: size)
        }
        defer { try? FileManager.default.removeItem(at: clip) }
        var smoothed = TakeEdit(sourceDuration: 3, aspect: .portrait)
        smoothed.voiceEnhancement = .off
        smoothed.skin = SkinPreset.studio.look
        var plain = smoothed
        plain.skin = SkinLook()
        let service = TakeEditService()
        let preview = try await service.previewItem(forVideoAt: clip, edit: smoothed)
        let previewPlain = try await service.previewItem(forVideoAt: clip, edit: plain)
        let exported = try await VideoExportService().export(
            videoAt: clip, options: ExportOptions(aspect: .portrait, edit: smoothed, shortSide: 1080, frameRate: 30)
        )
        defer { try? FileManager.default.removeItem(at: exported) }
        for time in [0.5, 1.5, 2.5] {
            let shown = try await still(preview.asset, composition: preview.videoComposition, at: time)
            let held = try await still(previewPlain.asset, composition: previewPlain.videoComposition, at: time)
            let written = try await still(AVURLAsset(url: exported), composition: nil, at: time)
            // The face is ~2% of the frame: the smoothing is measured where it works, in the face Vision finds in the plain still.
            let face = held.cgImage.flatMap { VisionFaceDetector().faces(in: CIImage(cgImage: $0)).first?.box }
            let match = difference(shown, written), effect = difference(shown, held, in: try #require(face, "no face at \(time) s"))
            note("SKIN SMOOTHING preview vs export at \(time) s · mean difference \(String(format: "%.2f", match)) of 255 · smoothing vs none on the face \(String(format: "%.2f", effect))")
            #expect(match < 3, "the export differs from the preview at \(time) s")
            #expect(effect > 0.5, "smoothing changed nothing on the face at \(time) s")
            Attachment.record(try #require(written.pngData()), named: "export-\(time).png")
            Attachment.record(try #require(held.pngData()), named: "without-\(time).png")
        }
    }

    /// A 4-second video exported without Skin, with the first engine at 100 and with every control of Skin at 100: how long each takes and the most
    /// memory the app took meanwhile (above what it had before), at 1080p and 4K.
    @Test(arguments: Resolution.allCases)
    func anExportWithSkinFinishesWithinItsMemory(_ resolution: Resolution) async throws {
        let source = try photo()
        let size = resolution.size
        let clip = try await SkinTestClip.make(seconds: 4, width: Int(size.width), height: Int(size.height)) { index in
            frame(index, of: source, size: size)
        }
        defer { try? FileManager.default.removeItem(at: clip) }
        var plain = TakeEdit(sourceDuration: 4, aspect: .portrait)
        plain.voiceEnhancement = .off
        var first = plain
        first.skin = .firstEngine(100)
        var skinned = plain
        skinned.skin = Self.top
        var lines: [String] = []
        for (name, edit) in [("without Skin", plain), ("first engine at 100", first), ("every control at 100", skinned)] {
            let base = MotionAnalysisDeviceTests.footprint()
            let peak = OSAllocatedUnfairLock(initialState: base)
            let watching = Task.detached {
                while !Task.isCancelled {
                    let now = MotionAnalysisDeviceTests.footprint()
                    peak.withLock { $0 = max($0, now) }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
            let started = ContinuousClock.now
            let exported = try await VideoExportService().export(
                videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: size.width, frameRate: 30)
            )
            let took = (ContinuousClock.now - started) / .seconds(1)
            watching.cancel()
            try? FileManager.default.removeItem(at: exported)
            lines.append("\(name) \(String(format: "%.1f", took)) s, memory +\((peak.withLock { $0 } - base) / 1_000_000) MB")
        }
        note("SKIN SMOOTHING export \(resolution.rawValue), 4 s · " + lines.joined(separator: " · "))
    }

    @Test func aVideoWithNoFaceIsUntouched() async throws {
        let clip = try await TestFootage.make(seconds: 2, width: 1080, height: 1920)
        defer { try? FileManager.default.removeItem(at: clip) }
        var smoothed = TakeEdit(sourceDuration: 2, aspect: .portrait)
        smoothed.voiceEnhancement = .off
        smoothed.skin = SkinPreset.studio.look
        var plain = smoothed
        plain.skin = SkinLook()
        let service = TakeEditService()
        let on = try await service.previewItem(forVideoAt: clip, edit: smoothed)
        let off = try await service.previewItem(forVideoAt: clip, edit: plain)
        for time in [0.5, 1.2] {
            let first = try await still(on.asset, composition: on.videoComposition, at: time)
            let second = try await still(off.asset, composition: off.videoComposition, at: time)
            #expect(difference(first, second) < 0.01, "a frame with no face changed at \(time) s")
        }
    }

    // MARK: - Frames

    @concurrent
    private func still(_ asset: AVAsset, composition: AVVideoComposition?, at time: Double) async throws -> UIImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.videoComposition = composition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return UIImage(cgImage: try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image)
    }

    /// The mean difference per channel of two stills drawn at 270 × 480.
    /// The mean gap inside `box` (the unit square, y up from the bottom edge, as Vision gives it).
    private func difference(_ first: UIImage, _ second: UIImage, in box: CGRect) -> Double {
        func bytes(_ image: UIImage) -> [UInt8] {
            var data = [UInt8](repeating: 0, count: 270 * 480 * 4)
            guard let cgImage = image.cgImage, let context = CGContext(
                data: &data, width: 270, height: 480, bitsPerComponent: 8, bytesPerRow: 270 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return data }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 270, height: 480))
            return data
        }
        let one = bytes(first), two = bytes(second)
        let columns = max(0, Int(box.minX * 270))..<min(270, Int(box.maxX * 270))
        let rows = max(0, Int((1 - box.maxY) * 480))..<min(480, Int((1 - box.minY) * 480))
        var total = 0, count = 0
        for row in rows {
            for column in columns {
                for channel in 0..<3 {
                    let index = (row * 270 + column) * 4 + channel
                    total += abs(Int(one[index]) - Int(two[index]))
                    count += 1
                }
            }
        }
        return count == 0 ? 0 : Double(total) / Double(count)
    }

    private func difference(_ first: UIImage, _ second: UIImage) -> Double {
        func bytes(_ image: UIImage) -> [UInt8] {
            var data = [UInt8](repeating: 0, count: 270 * 480 * 4)
            guard let cgImage = image.cgImage, let context = CGContext(
                data: &data, width: 270, height: 480, bitsPerComponent: 8, bytesPerRow: 270 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return data }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 270, height: 480))
            return data
        }
        let gaps = zip(bytes(first), bytes(second)).map { abs(Int($0) - Int($1)) }
        return Double(gaps.reduce(0, +)) / Double(gaps.count)
    }
}
