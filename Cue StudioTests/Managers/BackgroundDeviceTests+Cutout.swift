//
//  BackgroundDeviceTests+Cutout.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
import UIKit
import Vision
@testable import Cue_Studio

/// The automatic cutout on real takes of this iPhone, with the real Vision: how still the outline is from frame to frame before and after
/// it is steadied (`PersonMaskTrack`), and against Vision's own sequence handler; failures in a row held and faded; a fast pan and low
/// light made from the same frames; and the preview against the export with the creator moved over a color. Reads copies (hard links)
/// of the newest takes in the app's Takes folder, never changes them; nothing goes to Photos. `BACKGROUND …` lines carry the numbers.
///
/// `CUE_DEVICE=<iPhone> scripts/test.sh device "BackgroundDeviceTests/<test>()"` (the photo tests above need CUE_SKIN_MEDIA too).
extension BackgroundDeviceTests {
    /// Seconds of each take read.
    private static let readSeconds: Double = 12

    /// What Vision found in each frame of a take, in order.
    private struct Masks {
        let name: String
        let times: [TimeInterval]
        let raw: [PersonMaskFrame?]
    }

    /// The newest takes on this iPhone where Vision finds someone in the middle frame, linked into the temporary folder.
    private func takesWithSomeone(_ count: Int) async throws -> [URL] {
        var found: [URL] = []
        for original in MotionAnalysisDeviceTests.newestTakes(12) where found.count < count {
            let copy = URL.temporaryDirectory.appending(path: "cutout-\(UUID().uuidString).\(original.pathExtension)")
            do { try FileManager.default.linkItem(at: original, to: copy) } catch { try FileManager.default.copyItem(at: original, to: copy) }
            let duration = try await AVURLAsset(url: copy).load(.duration).seconds
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: copy))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 720, height: 720)
            if let frame = try? await generator.image(at: CMTime(seconds: duration / 2, preferredTimescale: 600)).image,
               let mask = PersonMasker.frame(for: CIImage(cgImage: frame), using: PersonMasker.makeRequest()), mask.coverage > 0.05 {
                found.append(copy)
            } else {
                try? FileManager.default.removeItem(at: copy)
            }
        }
        return found
    }

    /// Every frame of the first `readSeconds` of `url`, upright, through `change` (a pan, low light), handed to Vision with an image
    /// handler (the edit's way) or a sequence handler.
    private func masks(of url: URL, sequence: Bool = false, change: ((CIImage, Int) -> CIImage)? = nil) async throws -> Masks {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let transform = try await track.load(.preferredTransform)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: .zero, end: CMTime(seconds: Self.readSeconds, preferredTimescale: 600))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        defer { reader.cancelReading() }
        let request = PersonMasker.makeRequest()
        let handler = VNSequenceRequestHandler()
        var times: [TimeInterval] = [], raw: [PersonMaskFrame?] = []
        while let ready = try await provider.next() {
            ready.withUnsafeSampleBuffer { sample in
                guard let pixels = sample.imageBuffer else { return }
                autoreleasepool {
                    var image = FramePipeline.upright(pixels, transform: transform)
                    if let change { image = change(image, times.count) }
                    times.append(sample.presentationTimeStamp.seconds)
                    if sequence {
                        try? handler.perform([request], on: image)
                        raw.append(request.results?.first.flatMap { PersonMaskFrame(buffer: $0.pixelBuffer) })
                    } else {
                        raw.append(PersonMasker.frame(for: image, using: request))
                    }
                }
            }
        }
        return Masks(name: url.lastPathComponent, times: times, raw: raw)
    }

    /// The masks the edit shows, steadied in play order.
    private func steadied(_ masks: Masks, dropping dropped: Set<Int> = []) -> [PersonMaskTrack.Step] {
        var track = PersonMaskTrack()
        return masks.raw.enumerated().map { index, raw in track.next(dropped.contains(index) ? nil : raw, at: masks.times[index], epoch: 0) }
    }

    private struct Stillness {
        var meanOverlap = 0.0
        var lowestOverlap = 1.0
        var meanChange = 0.0
    }

    /// How alike each mask is to the one before (overlap of the person, mean change of the values).
    private func stillness(_ frames: [PersonMaskFrame?]) -> Stillness {
        var result = Stillness(), count = 0.0
        for (before, after) in zip(frames, frames.dropFirst()) {
            guard let before, let after else { continue }
            let overlap = after.overlap(with: before)
            result.meanOverlap += overlap
            result.lowestOverlap = min(result.lowestOverlap, overlap)
            result.meanChange += after.meanChange(from: before)
            count += 1
        }
        guard count > 0 else { return Stillness(meanOverlap: 0, lowestOverlap: 0, meanChange: 1) }
        result.meanOverlap /= count
        result.meanChange /= count
        return result
    }

    private static func format(_ stillness: Stillness) -> String {
        String(format: "overlap mean %.4f lowest %.3f · change %.4f", stillness.meanOverlap, stillness.lowestOverlap, stillness.meanChange)
    }

    @Test func theOutlineIsSteadyFrameToFrame() async throws {
        KeepScreenAwake.enable()
        let takes = try await takesWithSomeone(3)
        defer { takes.forEach { try? FileManager.default.removeItem(at: $0) } }
        guard !takes.isEmpty else {
            note("BACKGROUND stability: no take with a person on this iPhone · NOT VALIDATED")
            return
        }
        for take in takes {
            let started = ContinuousClock.now
            let masks = try await masks(of: take)
            let took = (ContinuousClock.now - started) / .seconds(1)
            let shown = steadied(masks)
            let sequence = try await self.masks(of: take, sequence: true)
            let raw = stillness(masks.raw), steady = stillness(shown.map(\.mask)), vision = stillness(sequence.raw)
            let failed = masks.raw.filter { $0 == nil }.count
            let held = shown.filter { $0.state == .held }.count, failures = shown.filter(\.state.isFailure).count
            var longest = 0, run = 0
            for raw in masks.raw {
                run = raw == nil ? run + 1 : 0
                longest = max(longest, run)
            }
            // While the outline moves (consecutive raw masks overlap less than 0.95), how close the steadied mask stays to Vision's.
            var following: [Double] = []
            for index in 1..<masks.raw.count {
                guard let now = masks.raw[index], let before = masks.raw[index - 1], now.overlap(with: before) < 0.95,
                      let shownNow = shown[index].mask else { continue }
                following.append(shownNow.overlap(with: now))
            }
            let follow = following.isEmpty ? 1 : following.reduce(0, +) / Double(following.count)
            note(
                "BACKGROUND stability \(masks.name) · \(masks.raw.count) frames in \(String(format: "%.1f", took)) s"
                    + " · Vision per frame: \(Self.format(raw)) · steadied: \(Self.format(steady)) · Vision sequence: \(Self.format(vision))"
                    + " · Vision failed \(failed) (longest run \(longest)) · held \(held) · past the hold \(failures)"
                    + " · moving frames \(following.count), steadied vs Vision \(String(format: "%.3f", follow))"
            )
            #expect(steady.meanChange <= raw.meanChange + 0.000_1, "steadying made the outline shimmer more")
            #expect(steady.meanOverlap >= raw.meanOverlap - 0.002)
            #expect(follow > 0.85, "the steadied outline trails behind a movement: \(follow)")
        }
    }

    @Test func failuresInARowAreHeldThenFade() async throws {
        KeepScreenAwake.enable()
        let take = try #require(try await takesWithSomeone(1).first, "No take with a person on this iPhone")
        defer { try? FileManager.default.removeItem(at: take) }
        let masks = try await masks(of: take)
        for length in [3, 10, 15, 30] {
            // `length` frames in a row without a mask from the second second.
            let start = masks.times.firstIndex { $0 >= 2 } ?? 0
            let dropped = Set(start..<min(masks.raw.count, start + length))
            let shown = steadied(masks, dropping: dropped)
            let inside = dropped.sorted().map { shown[$0] }
            let held = inside.filter { $0.state == .held }.count
            let original = inside.filter { $0.mask == nil }.count
            let firstFailure = inside.firstIndex { $0.state.isFailure }.map { masks.times[start + $0] - masks.times[start] }
            note(
                "BACKGROUND \(length) failed frames in a row (\(String(format: "%.2f", Double(length) / 30)) s): held \(held),"
                    + " fading \(inside.filter { $0.state == .fading }.count), as recorded \(original)"
                    + (firstFailure.map { String(format: ", first failure shown %.2f s after the first failed frame", $0) } ?? "")
            )
            let lastGood = shown[start - 1].mask
            // Within the hold every frame keeps the outline before it: none shows the original background.
            for (offset, step) in inside.enumerated() where masks.times[start + offset] - masks.times[start - 1] <= PersonMaskTrack.holdLimit {
                #expect(step.mask == lastGood && step.state == .held)
            }
            if length <= 10 { #expect(original == 0, "a short failure showed the original background") }
        }
    }

    @Test func aFastPanAndLowLight() async throws {
        KeepScreenAwake.enable()
        let take = try #require(try await takesWithSomeone(1).first, "No take with a person on this iPhone")
        defer { try? FileManager.default.removeItem(at: take) }
        // A pan of 2% of the frame a frame, back and forth every second, and the frame 2.5 stops darker.
        let panned = try await masks(of: take) { image, index in
            let extent = image.extent
            let phase = Double(index % 60) / 60
            let shift = (phase < 0.5 ? phase : 1 - phase) * 2 * 0.3 * extent.width
            return image.clampedToExtent().transformed(by: CGAffineTransform(translationX: shift, y: 0)).cropped(to: extent)
        }
        let dark = try await masks(of: take) { image, _ in image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -2.5]) }
        let plain = try await masks(of: take)
        for (name, masks) in [("plain", plain), ("fast pan", panned), ("2.5 stops darker", dark)] {
            let shown = steadied(masks)
            var following: [Double] = []
            for index in masks.raw.indices {
                guard let now = masks.raw[index], let shownNow = shown[index].mask else { continue }
                following.append(shownNow.overlap(with: now))
            }
            let follow = following.isEmpty ? 0 : following.reduce(0, +) / Double(following.count)
            let coverage = masks.raw.compactMap { $0?.coverage }
            note(
                "BACKGROUND \(name) · person \(String(format: "%.1f", 100 * coverage.reduce(0, +) / Double(max(1, coverage.count))))% of the frame"
                    + " · Vision failed \(masks.raw.filter { $0 == nil }.count) · held \(shown.filter { $0.state == .held }.count)"
                    + " · past the hold \(shown.filter(\.state.isFailure).count) · steadied vs Vision \(String(format: "%.3f", follow))"
                    + " · steadied \(Self.format(stillness(shown.map(\.mask)))) · Vision \(Self.format(stillness(masks.raw)))"
            )
            #expect(follow > 0.85, "\(name): the steadied outline is away from Vision's: \(follow)")
        }
    }

    @Test func thePreviewIsTheExportWithTheCreatorMoved() async throws {
        KeepScreenAwake.enable()
        let take = try #require(try await takesWithSomeone(1).first, "No take with a person on this iPhone")
        defer { try? FileManager.default.removeItem(at: take) }
        let duration = try await AVURLAsset(url: take).load(.duration).seconds
        var edit = TakeEdit(sourceDuration: duration, aspect: .portrait)
        edit.voiceEnhancement = .off
        edit.timeline.trimEnd(to: min(duration, 6))
        var effect = BackgroundEffect(style: .color)
        effect.color = .blue
        effect.person = PersonPlacement(center: OverlayPoint(x: 0.4, y: 0.6), scale: 0.7)
        edit.setBackground(effect, for: nil)
        let sounds = RecordingSoundCache()
        let preview = try await EditRenderRequest.prepare(
            source: take, edit: edit, purpose: .editorPreview(rendersCurveSound: true), sounds: sounds
        ).build()
        let export = try await EditRenderRequest.prepare(
            source: take, edit: edit, purpose: .export(burnsInCaptions: true, shortSide: 1080, frameRate: 30), sounds: sounds
        ).build()
        let size = CGSize(width: 180, height: 320)
        // The export played in order (as it is written), against the preview asked frame by frame (a paused, scrubbed preview).
        let times: [Double] = [1, 2.5, 4, 5.5]
        let written = try await Self.framesInOrder(export.asset, composition: export.videoComposition, at: times)
        let writtenAgain = try await Self.framesInOrder(export.asset, composition: export.videoComposition, at: times)
        var lines: [String] = []
        for (index, time) in times.enumerated() {
            let shown = try await RenderParity.frame(preview.asset, composition: preview.videoComposition, at: edit.timeline.reachableLeadIn + time)
            let scrubbed = try RenderParity.meanDifference(shown, written[index], size: size)
            let again = try RenderParity.meanDifference(written[index], writtenAgain[index], size: size)
            lines.append(String(format: "%.1f s: scrubbed preview vs export %.2f, export vs export %.2f", time, scrubbed, again))
            #expect(again < 0.5, "two exports differ at \(time) s: \(again)")
            #expect(scrubbed < 4, "the preview differs from the export at \(time) s: \(scrubbed)")
            if index == 1 { Attachment.record(UIImage(cgImage: written[index]).pngData() ?? Data(), named: "cutout-moved.png") }
        }
        note("BACKGROUND preview vs export, moved to 40%/60% at 70% over blue (of 255): " + lines.joined(separator: " · "))
    }

    /// The composition's frames at `times`, read start to end as an export reads them.
    @concurrent
    private static func framesInOrder(_ asset: AVAsset, composition: AVVideoComposition?, at times: [Double]) async throws -> [CGImage] {
        let reader = try AVAssetReader(asset: asset)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let output = AVAssetReaderVideoCompositionOutput(videoTracks: tracks, videoSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.videoComposition = composition
        let provider = reader.outputProvider(for: output)
        try reader.start()
        defer { reader.cancelReading() }
        let context = CIContext()
        var images: [CGImage] = []
        var wanted = times[...]
        while let next = wanted.first, let ready = try await provider.next() {
            let picture = ready.withUnsafeSampleBuffer { sample -> CGImage? in
                guard sample.presentationTimeStamp.seconds + 0.5 / 30 >= next, let pixels = sample.imageBuffer else { return nil }
                let image = CIImage(cvPixelBuffer: pixels)
                return context.createCGImage(image, from: image.extent)
            }
            guard let picture else { continue }
            images.append(picture)
            wanted = wanted.dropFirst()
        }
        return images
    }
}
