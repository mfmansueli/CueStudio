//
//  EyeContactCompositionTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Eye Contact in a built composition: every stretch that plays a recording carries that recording's decisions (the other side of
/// a dissolve too), nothing else does, and nothing at all while it's off.
@Suite("Eye Contact in the composition")
struct EyeContactCompositionTests {
    @Test func eachStretchCarriesItsRecordingsDecisions() async throws {
        let clip = try await TestClip.make(seconds: 6)
        defer {
            EyeContactAnalysisStore.remove(forRecording: clip)
            try? FileManager.default.removeItem(at: clip)
        }
        var analysis = EyeTestData.analysis(seconds: 6, fileStamp: EyeContactAnalysisStore.fileStamp(of: clip))
        analysis.width = 360
        analysis.height = 640
        EyeContactAnalysisStore.save(analysis, forRecording: clip)
        var edit = TakeEdit(sourceDuration: 6, aspect: .portrait)
        edit.timeline.split(atEdited: 3)
        edit.eyeContact = EyeContactSettings(strength: 1)
        let options = EditedComposition.Options(burnsInCaptions: false, analyzesMissingEyes: false)
        let built = try await EditedComposition.build(source: clip, edit: edit, options: options)
        let instructions = built.videoComposition.instructions.compactMap { $0 as? CompositionInstruction }
        #expect(!instructions.isEmpty)
        for instruction in instructions {
            let track = try #require(instruction.frame.eyes)
            let middle = (instruction.timeRange.start.seconds + instruction.timeRange.end.seconds) / 2
            #expect(track.frame(at: instruction.sourceTime(at: middle)) != nil)
        }
        edit.eyeContact = nil
        let off = try await EditedComposition.build(source: clip, edit: edit, options: options)
        let carried = off.videoComposition.instructions.compactMap { ($0 as? CompositionInstruction)?.frame.eyes }
        #expect(carried.isEmpty)
    }

    /// A cover taken from a frame shows the eyes the video shows there; a photo picked as the cover is never touched.
    @Test func aFrameCoverGetsTheVideosEyesAndAPhotoCoverDoesnt() async throws {
        let clip = try await TestFootage.make(seconds: 3, width: 360, height: 640)
        defer {
            EyeContactAnalysisStore.remove(forRecording: clip)
            try? FileManager.default.removeItem(at: clip)
        }
        var analysis = EyeTestData.analysis(seconds: 3, fileStamp: EyeContactAnalysisStore.fileStamp(of: clip))
        analysis.width = 360
        analysis.height = 640
        EyeContactAnalysisStore.save(analysis, forRecording: clip)
        var edit = TakeEdit(sourceDuration: 3, aspect: .portrait)
        edit.cover = VideoCover(source: .frame(1.5))
        let plain = try #require(await CoverRenderer.picture(for: .frame(1.5), videoURL: clip, edit: edit)?.cgImage)
        edit.eyeContact = EyeContactSettings(strength: 1)
        let corrected = try #require(await CoverRenderer.picture(for: .frame(1.5), videoURL: clip, edit: edit)?.cgImage)
        #expect(RenderedPixels(CIImage(cgImage: plain)).luma(in: CGRect(x: 0, y: 0, width: 360, height: 640))
            != RenderedPixels(CIImage(cgImage: corrected)).luma(in: CGRect(x: 0, y: 0, width: 360, height: 640)))
        // A photo: the same with Eye Contact on or off.
        let photo = try EditMediaFiles.link(try Self.photo())
        defer { EditMediaFiles.remove([photo]) }
        let photoOn = await CoverRenderer.picture(for: .photo(fileName: photo), videoURL: clip, edit: edit)?.pngData()
        edit.eyeContact = nil
        let photoOff = await CoverRenderer.picture(for: .photo(fileName: photo), videoURL: clip, edit: edit)?.pngData()
        #expect(photoOn != nil && photoOn == photoOff)
    }

    private static func photo() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "cover-\(UUID().uuidString).png")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 90, height: 160)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 90, height: 160))
        }
        try #require(image.pngData()).write(to: url)
        return url
    }
}
