//
//  SplitScreenCaptureTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Cue_Studio

/// Pictures of the split screen drawn by the editor's preview, to look at: each seam (none, line, blur, shadow), with a
/// caption on the seam, the main video on the bottom and on top, 60/40, side by side. Opt-in, from two videos of a folder:
/// `TEST_RUNNER_CUE_SPLIT_CAPTURE=<folder with main.mov and support.mov> scripts/test.sh only "Cue StudioTests/SplitScreenCaptureTests"`;
/// the pictures go to the same folder.
@MainActor
@Suite("Split screen captures", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_SPLIT_CAPTURE"] != nil))
struct SplitScreenCaptureTests {
    @Test func captureTheLayoutsAndSeams() async throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["CUE_SPLIT_CAPTURE"]), isDirectory: true)
        let main = folder.appending(path: "main.mov")
        let supportFile = folder.appending(path: "support.mov")
        let name = try EditMediaFiles.link(supportFile)
        defer { EditMediaFiles.remove([name]) }
        let duration = try await AVURLAsset(url: main).load(.duration).seconds
        let supportLength = try await AVURLAsset(url: supportFile).load(.duration).seconds
        var support = MediaOverlay(kind: .video, fileName: name, aspect: 1, mediaDuration: supportLength, span: TimeSpan(start: 1, end: duration - 0.5))
        support.layout = .split
        support.followsCuts = true
        let shots: [(String, SplitLayout, Bool)] = [
            ("none", SplitLayout(), true), ("line", SplitLayout(seam: .line), true), ("blur", SplitLayout(seam: .blur), true),
            ("shadow", SplitLayout(seam: .shadow), true),
            ("main-top-6040", SplitLayout(ratio: .sixtyForty, first: .main, larger: .main, seam: .blur), true),
            ("side-by-side", SplitLayout(arrangement: .sideBySide, seam: .line), false),
        ]
        for (label, layout, onSeam) in shots {
            var edit = TakeEdit(sourceDuration: duration, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.splitScreen.setLayout(layout)
            edit.splitScreen.captionsOnSeam = onSeam
            edit.media = [support]
            edit.showsCaptions = true
            edit.captions = [CaptionCue(text: "não dá cheiro no freezer", start: 2, end: 5)]
            let item = try await TakeEditService().previewItem(forVideoAt: main, edit: edit, purpose: .editorPreview(rendersCurveSound: false))
            let generator = AVAssetImageGenerator(asset: item.asset)
            generator.videoComposition = item.videoComposition
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            let image = try await generator.image(at: CMTime(seconds: 3, preferredTimescale: 600)).image
            let url = folder.appending(path: "split-\(label).png")
            let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            #expect(CGImageDestinationFinalize(destination))
        }
    }
}
