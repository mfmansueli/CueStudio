//
//  LegacyCaptionLookTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Edits saved by earlier versions draw their captions exactly as they did. The fixtures are edits written by the version that
/// made them (`legacy-caption-looks.json`: each edit's JSON, where its lines sat and when, and pictures of a state of each
/// line, `legacy-caption-<case>-<n>.png`), so a new reading of the presets, a new control or a new renderer can never
/// restyle a video someone already made. Recorded once with `TEST_RUNNER_CUE_RECORD_CAPTION_LOOKS=<folder on the Mac>`,
/// from the code that made those edits; never re-recorded to make a change pass.
@MainActor
@Suite("Legacy caption looks")
struct LegacyCaptionLookTests {
    private final class BundleToken {}

    private static let frame = CGSize(width: 540, height: 960)
    /// The moments each case is pictured at: a word being said early in the first line, and one in the second.
    private static let moments: [TimeInterval] = [0.7, 3.6]

    // MARK: - Fixture

    struct Shape: Codable, Equatable {
        var text: String
        var start: Double
        var end: Double
        var width: Double
        var height: Double
        var x: Double
        var y: Double
        var fade: Double
        var fadeIn: Double
        var fadeOut: Double
        var popScale: Double
        var popDuration: Double
        var lit: Int?
    }

    struct Case: Codable {
        var name: String
        /// The edit as its version wrote it.
        var edit: Data
        var shapes: [Shape]
        var shots: [String]
    }

    // MARK: - The edits

    private static func cue(_ words: [String], from start: TimeInterval) -> CaptionCue {
        CaptionCue(words: words.enumerated().map { index, word in
            CaptionWord(text: word, start: start + Double(index) * 0.4, end: start + Double(index) * 0.4 + 0.34)
        })
    }

    private static var lines: [CaptionCue] {
        [
            cue(["Every", "idea", "deserves", "a", "stage."], from: 0.2),
            cue(["This", "is", "where", "most", "people", "stop,", "and", "you", "keep", "going."], from: 2.4),
        ]
    }

    private static func edit(_ change: (inout TakeEdit) -> Void) -> TakeEdit {
        var edit = TakeEdit(sourceDuration: 8, aspect: .portrait)
        edit.showsCaptions = true
        edit.captions = lines
        change(&edit)
        return edit
    }

    /// A collection look as an edit saved before Reveal and the complete presets has it: the first reading, the word lit.
    private static func firstReading(_ theme: CaptionTheme) -> CaptionSettings {
        var settings = CaptionSettings.savedBeforeMotion(theme, version: nil)
        settings.followsWords = true
        return settings
    }

    /// A collection look as picked in Caption style before motion: the complete preset with its own reveal.
    private static func complete(_ edit: inout TakeEdit, _ theme: CaptionTheme) {
        let settings = CaptionSettings.savedBeforeMotion(theme)
        edit.captionCollection = settings
        edit.captionAnimation = settings.spec.animation
    }

    static var cases: [(name: String, edit: TakeEdit)] {
        var cases: [(String, TakeEdit)] = []
        for theme in [CaptionTheme.cue, .impact, .clean, .pop, .editorial] {
            cases.append(("v1-\(theme.rawValue)", edit { $0.captionCollection = firstReading(theme) }))
        }
        for theme in [CaptionTheme.cue, .impact, .clean, .pop, .editorial, .educational, .interview] {
            cases.append(("v2-\(theme.rawValue)", edit { complete(&$0, theme) }))
        }
        cases.append(("v2-cue-box", edit { complete(&$0, .cue); $0.captionAnimation = .box }))
        cases.append(("v2-impact-words", edit { complete(&$0, .impact); $0.captionAnimation = .groups }))
        cases.append(("v2-editorial-fade", edit { complete(&$0, .editorial); $0.captionAnimation = .fade; $0.captionCollection?.followsWords = false }))
        cases.append(("v2-educational-line", edit { complete(&$0, .educational); $0.captionAnimation = .line; $0.captionCollection?.followsWords = false }))
        cases.append(("v2-cue-two-lines", edit { complete(&$0, .cue); $0.captionCollection?.format = .twoLines }))
        cases.append(("v2-pop-tuned", edit { edit in
            complete(&edit, .pop)
            edit.captionCollection?.accent = .lime
            edit.captionCollection?.face = .montserrat
            edit.captionCollection?.sizeScale = 1.35
            edit.captionCollection?.center = OverlayPoint(x: 0.5, y: 0.2)
        }))
        cases.append(("v2-cue-copied-launch", edit { edit in
            complete(&edit, .cue)
            edit.captionCollection?.customLook = TypePreset.launch.look(for: .caption)
        }))
        cases.append(("v2-interview-copied-paper-box", edit { edit in
            complete(&edit, .interview)
            edit.captionCollection?.customLook = TypePreset.paper.look(for: .caption)
            edit.captionAnimation = .box
            edit.captionCollection?.followsWords = true
        }))
        cases.append(("v2-impact-line-emphasized", edit { edit in
            complete(&edit, .impact)
            edit.captions[0].lineStyle = CaptionLineStyle(isEmphasized: true)
        }))
        cases.append(("v2-cue-line-biggest", edit { edit in
            complete(&edit, .cue)
            edit.captions[1].lineStyle = CaptionLineStyle(size: .biggest)
        }))
        cases.append(("v2-editorial-arabic", edit { edit in
            complete(&edit, .editorial)
            edit.captions = [cue(["مرحبا", "بكم", "في", "القناة"], from: 0.2), cue(["هذا", "هو", "المكان", "الذي", "يتوقف", "فيه", "الناس."], from: 2.4)]
        }))
        cases.append(("v2-cue-japanese", edit { edit in
            complete(&edit, .cue)
            edit.captions = [cue(["今日は", "新しい", "動画を", "作ります"], from: 0.2), cue(["ここで", "多くの", "人が", "止まります"], from: 2.4)]
        }))
        cases.append(("type-look-cue-highlight", edit { edit in
            edit.captionCollection = nil
            edit.captionLook = TypePreset.cue.look(for: .caption)
            edit.captionPreset = .cue
            edit.captionAnimation = .highlight
        }))
        cases.append(("old-style-classic", edit { edit in
            edit.captionCollection = nil
            edit.captionStyle = .classic
        }))
        return cases
    }

    // MARK: - Drawing

    private static func shapes(_ overlays: [FrameOverlay]) -> [Shape] {
        overlays.map { overlay in
            Shape(
                text: overlay.lazyText?.text.text ?? "", start: overlay.span?.start ?? -1, end: overlay.span?.end ?? -1,
                width: overlay.size.width, height: overlay.size.height, x: overlay.origin.x, y: overlay.origin.y,
                fade: overlay.fade, fadeIn: overlay.fadeIn, fadeOut: overlay.fadeOut, popScale: overlay.popScale,
                popDuration: overlay.popDuration, lit: overlay.lazyText?.emphasis?.index
            )
        }
    }

    /// The states on screen at `moments`, drawn as the compositor draws them.
    private static func shots(_ overlays: [FrameOverlay]) throws -> [CGImage] {
        let cache = OverlayImageCache()
        let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])
        return try moments.compactMap { time in
            guard let overlay = overlays.first(where: { $0.isVisible(at: time) }) else { return nil }
            let image = try #require(overlay.image ?? overlay.lazyText.flatMap(cache.image(for:)))
            return context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        }
    }

    private static func pixels(_ image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    // MARK: - Tests

    private static func fixture() throws -> [Case] {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "legacy-caption-looks", withExtension: "json"))
        return try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
    }

    @Test func everyRecordedCaseIsStillChecked() throws {
        let recorded = try Self.fixture().map(\.name)
        #expect(recorded == Self.cases.map(\.name))
    }

    @Test func savedEditsDrawTheirCaptionsAsTheyWereMade() throws {
        for recorded in try Self.fixture() {
            let report = DecodingReport()
            let edit = try JSONDecoder.library.reporting(to: report).decode(TakeEdit.self, from: recorded.edit)
            #expect(report.notes.isEmpty, "\(recorded.name): \(report.notes)")
            let overlays = EditedComposition.captionOverlays(for: edit, frame: Self.frame)
            let shapes = Self.shapes(overlays)
            #expect(shapes.count == recorded.shapes.count, "\(recorded.name): \(shapes.count) states, recorded \(recorded.shapes.count)")
            for (now, then) in zip(shapes, recorded.shapes) where now != then {
                Issue.record("\(recorded.name): \(now) is not \(then)")
                break
            }
            let shots = try Self.shots(overlays)
            #expect(shots.count == recorded.shots.count, "\(recorded.name)")
            for (shot, name) in zip(shots, recorded.shots) {
                let base = (name as NSString).deletingPathExtension
                let url = try #require(Bundle(for: BundleToken.self).url(forResource: base, withExtension: "png"), "\(name) missing")
                let then = try #require(UIImage(contentsOfFile: url.path)?.cgImage)
                guard shot.width == then.width, shot.height == then.height else {
                    Issue.record("\(name): \(shot.width)×\(shot.height), recorded \(then.width)×\(then.height)")
                    continue
                }
                let now = Self.pixels(shot), old = Self.pixels(then)
                // Glyph edges may round a step apart between system versions: a few pixels, never a different look.
                let differing = stride(from: 0, to: now.count, by: 4).filter { index in
                    (0..<4).contains { abs(Int(now[index + $0]) - Int(old[index + $0])) > 24 }
                }.count
                #expect(Double(differing) / Double(now.count / 4) < 0.004, "\(name): \(differing) pixels differ")
            }
        }
    }

    /// Writes the fixture from the code of the version whose edits it keeps.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CUE_RECORD_CAPTION_LOOKS"] != nil))
    func record() throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["CUE_RECORD_CAPTION_LOOKS"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var recorded: [Case] = []
        for (name, edit) in Self.cases {
            let data = try JSONEncoder.library.encode(edit)
            let overlays = EditedComposition.captionOverlays(for: edit, frame: Self.frame)
            var shots: [String] = []
            for (index, shot) in try Self.shots(overlays).enumerated() {
                let file = "legacy-caption-\(name)-\(index).png"
                try #require(UIImage(cgImage: shot).pngData()).write(to: folder.appendingPathComponent(file))
                shots.append(file)
            }
            recorded.append(Case(name: name, edit: data, shapes: Self.shapes(overlays), shots: shots))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(recorded).write(to: folder.appendingPathComponent("legacy-caption-looks.json"))
    }
}
