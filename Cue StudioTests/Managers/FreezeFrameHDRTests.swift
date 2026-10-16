//
//  FreezeFrameHDRTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// Freeze frame on an HDR recording (made here: HEVC Main 10, BT.2020, HLG, turned like a portrait take): the still is HDR
    /// too, 10 bits with the recording's color tags and transform, holding the very frame; in an export it comes out like the
    /// clip it was taken from.
    @MainActor
    @Suite("Freeze frame HDR", .serialized, .timeLimit(.minutes(10)))
    struct FreezeFrameHDRTests {
        @Test func theStillOfAnHDRTakeIsHDRWithItsTagsAndItsFrame() async throws {
            let take = try await HDRTestClip.make(seconds: 3)
            defer { try? FileManager.default.removeItem(at: take) }
            let source = try #require(try await AVURLAsset(url: take).loadTracks(withMediaType: .video).first)
            try #require(try await source.load(.mediaCharacteristics).contains(.containsHDRVideo), "The test clip isn't HDR")

            let name = try await StillClipWriter.write(frameOf: take, at: 1.5, length: 5)
            defer { EditMediaFiles.remove([name]) }
            let still = AVURLAsset(url: EditMediaFiles.url(for: name))
            let track = try #require(try await still.loadTracks(withMediaType: .video).first)
            let (characteristics, formats, transform) = try await track.load(.mediaCharacteristics, .formatDescriptions, .preferredTransform)
            #expect(characteristics.contains(.containsHDRVideo))
            let format = try #require(formats.first)
            #expect(CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_HEVC)
            func tag(_ key: CFString) -> String? { CMFormatDescriptionGetExtension(format, extensionKey: key) as? String }
            #expect(tag(kCMFormatDescriptionExtension_TransferFunction) == kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG as String)
            #expect(tag(kCMFormatDescriptionExtension_ColorPrimaries) == kCMFormatDescriptionColorPrimaries_ITU_R_2020 as String)
            #expect(tag(kCMFormatDescriptionExtension_YCbCrMatrix) == kCMFormatDescriptionYCbCrMatrix_ITU_R_2020 as String)
            #expect((CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_BitsPerComponent) as? Int) == 10)
            #expect(transform == HDRTestClip.transform)
            #expect(abs(try await still.load(.duration).seconds - 5) < 0.1)
            // The frame itself: second 1's color, 10 bits, within the codec's rounding.
            let held = try await HDRTestClip.centerSample(at: 3, in: EditMediaFiles.url(for: name))
            let color = HDRTestClip.colors[1]
            #expect(abs(held.y - Int(color.y)) <= 6 && abs(held.cb - Int(color.cb)) <= 6 && abs(held.cr - Int(color.cr)) <= 6, "\(held)")
        }

        /// The Simulator's VideoToolbox can't turn an HLG frame into the compositor's BGRA (-12905, measured: the HDR take alone
        /// fails to export there, with or without a freeze frame; the same clip tagged BT.709 exports), so this one runs on an iPhone.
        @Test(.enabled(if: ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil, "HLG exports only on an iPhone"))
        func anExportShowsTheFrozenFrameLikeTheClipItCameFrom() async throws {
            let take = try await HDRTestClip.make(seconds: 3)
            defer { try? FileManager.default.removeItem(at: take) }
            let name = try await StillClipWriter.write(frameOf: take, at: 1.5, length: 5)
            defer { EditMediaFiles.remove([name]) }
            var edit = TakeEdit(sourceDuration: 3, aspect: .portrait)
            edit.voiceEnhancement = .off
            let source = ClipSource(fileName: name, duration: 5, title: "Freeze frame")
            edit.timeline.split(atEdited: 1.5)
            edit.timeline.insertClip(source: source.id, duration: 5, span: TimeSpan(start: 0, end: 2), at: 1)
            edit.sources = [source]
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 360, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(abs(try await AVURLAsset(url: output).load(.duration).seconds - 5) < 0.1)
            // Second 1 of the take (1.2 s) and the frozen frame (2.5 s) come out the same color.
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: output))
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            let clip = try TestClip.centerColor(of: try await generator.image(at: CMTime(seconds: 1.2, preferredTimescale: 600)).image)
            let frozen = try TestClip.centerColor(of: try await generator.image(at: CMTime(seconds: 2.5, preferredTimescale: 600)).image)
            #expect(zip(clip, frozen).allSatisfy { abs($0 - $1) <= 6 }, "clip \(clip), frozen \(frozen)")
        }

        @Test func anSDRTakesStillStaysSDR() async throws {
            let take = try await TestClip.make(seconds: 2)
            defer { try? FileManager.default.removeItem(at: take) }
            let name = try await StillClipWriter.write(frameOf: take, at: 1, length: 2)
            defer { EditMediaFiles.remove([name]) }
            let track = try #require(try await AVURLAsset(url: EditMediaFiles.url(for: name)).loadTracks(withMediaType: .video).first)
            #expect(!(try await track.load(.mediaCharacteristics)).contains(.containsHDRVideo))
            let format = try #require(try await track.load(.formatDescriptions).first)
            #expect(CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_H264)
        }
    }
}
