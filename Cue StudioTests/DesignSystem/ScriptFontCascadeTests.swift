//
//  ScriptFontCascadeTests.swift
//  Cue StudioTests
//

import CoreText
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// The one resolver every word on the video goes through: each script draws in a face that has it (never a box), Latin keeps
/// the style's face in mixed text, a library family drawn first once its file is here, Vietnamese moved whole to a face that
/// has its letters, and captions, texts and the cover asking for the same face.
@MainActor
@Suite("Script font cascade")
struct ScriptFontCascadeTests {
    static let samples: [(language: String, text: String)] = [
        ("ja", "Day 1 の朝ごはん"), ("zh-Hans", "旅行第一天早上"), ("zh-Hant", "這是我的第一天"), ("ko", "여행 첫날 아침"),
        ("ar", "اليوم الأول من رحلتي"), ("hi", "मेरी यात्रा का पहला दिन"), ("th", "วันแรกของการเดินทาง"),
    ]

    /// The face Core Text draws each piece of `text` in, piece by piece (spaces left out).
    nonisolated static func runs(_ text: String, font: UIFont) -> [(text: String, font: String)] {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        let string = text as NSString
        return runs.compactMap { run in
            let range = CTRunGetStringRange(run)
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = attributes[kCTFontAttributeName] as! CTFont // swiftlint:disable:this force_cast
            let piece = string.substring(with: NSRange(location: range.location, length: range.length))
            // A space between two scripts goes to either face: only the letters say which face draws what.
            guard !piece.allSatisfy(\.isWhitespace) else { return nil }
            return (piece, CTFontCopyPostScriptName(runFont) as String)
        }
    }

    @Test(arguments: TextOverlayFont.editorFonts)
    func everyFamilyDrawsEveryScript(_ face: TextOverlayFont) {
        for sample in Self.samples {
            let font = TextFont.font(face, weight: .bold, size: 30, text: sample.text)
            for run in Self.runs(sample.text, font: font) {
                #expect(run.font != "LastResort", "\(face) \(sample.language): \(run.text) has no face")
            }
        }
    }

    @Test func mixedTextKeepsLatinInTheStylesFace() {
        let font = TextFont.font(.montserrat, weight: .heavy, size: 30, text: "Day 1 の朝")
        let runs = Self.runs("Day 1 の朝", font: font)
        let latin = runs.filter { $0.text.contains("Day") }
        let japanese = runs.filter { $0.text.contains("の") }
        #expect(latin.allSatisfy { $0.font.hasPrefix("Montserrat") }, "\(runs)")
        #expect(japanese.allSatisfy { $0.font.hasPrefix("HiraginoSans") || $0.font.contains("Kaku") }, "\(runs)")
        // A heavy style gets the heavy Japanese gothic.
        #expect(japanese.contains { $0.font == "HiraginoSans-W8" }, "\(runs)")
    }

    /// The pieces of `text` in another script than Latin, and the face each is drawn in.
    private static func scriptRuns(_ text: String, _ face: TextOverlayFont, _ weight: TextOverlayWeight) -> [(text: String, font: String)] {
        runs(text, font: TextFont.font(face, weight: weight, size: 30, text: text)).filter { !$0.text.contains("Day") }
    }

    @Test func eachStyleKeepsItsCharacterInTheSystemsFaces() {
        let serif = Self.scriptRuns("Day 1 朝ごはん", .dmSerif, .regular)
        #expect(!serif.isEmpty && serif.allSatisfy { $0.font.hasPrefix("HiraMin") }, "\(serif)")
        let thai = Self.scriptRuns("Day 1 วันแรก", .anton, .regular)
        #expect(!thai.isEmpty && thai.allSatisfy { $0.font == "Thonburi-Bold" }, "\(thai)")
        let hindi = Self.scriptRuns("Day 1 पहला दिन", .montserrat, .heavy)
        #expect(!hindi.isEmpty && hindi.allSatisfy { $0.font == "Poppins-ExtraBold" }, "\(hindi)")
        // Rubik and Poppins have Arabic and Devanagari of their own: the style's face draws them.
        let arabic = Self.runs("مرحبا", font: TextFont.font(.rubik, weight: .bold, size: 30, text: "مرحبا"))
        #expect(arabic.allSatisfy { $0.font.hasPrefix("Rubik") }, "\(arabic)")
    }

    @Test func aLineAllInAnotherScriptIsSetAsItAlwaysWasUntilItsFamilyArrives() {
        // No Latin to keep: the system font at the style's weight, with the system's own faces (a video made before the
        // libraries keeps its line height and look).
        let arabic = TextFont.font(.dmSerif, weight: .regular, size: 30, text: "مرحبا بكم")
        #expect(!arabic.fontName.hasPrefix("DMSerif"), "\(arabic.fontName)")
        #expect(Self.runs("مرحبا بكم", font: arabic).allSatisfy { $0.font != "LastResort" && !$0.font.hasPrefix("DMSerif") })
        let editorial = CaptionStyleSpec.spec(for: .editorial, version: CaptionStyleSpec.currentVersion)
        let caption = CaptionFont.font(spec: editorial, size: 30, text: "朝ごはん")
        #expect(caption.fontName.hasPrefix("."), "\(caption.fontName)")
    }

    @Test func aLibraryFamilyComesFirstOnceItsFileIsHere() throws {
        let registry = FontPackRegistry()
        let mukta = try #require(FontPackManifest.bundled.pack("mukta"))
        let base = TextFont.font(.dmSans, weight: .bold, size: 30, text: "")
        let before = Self.runs("पहला दिन", font: ScriptFontCascade.font(base, character: .sans, weight: .bold, text: "पहला दिन", registry: registry))
        #expect(before.allSatisfy { $0.font.hasPrefix("KohinoorDevanagari") }, "\(before)")
        // A registered face stands in for Mukta's file (Poppins draws Devanagari): it is drawn before the system's.
        registry.add(mukta, mukta.file(for: .bold), postScriptName: "Poppins-Bold")
        let after = Self.runs("पहला दिन", font: ScriptFontCascade.font(base, character: .sans, weight: .bold, text: "पहला दिन", registry: registry))
        #expect(after.allSatisfy { $0.font == "Poppins-Bold" }, "\(after)")
        #expect(Self.runs("Day", font: ScriptFontCascade.font(base, character: .sans, weight: .bold, text: "Day पहला", registry: registry))
            .allSatisfy { $0.font.hasPrefix("DMSans") })
    }

    @Test func aFileThatArrivesDuringAnExportWaitsForItsEnd() throws {
        let registry = FontPackRegistry()
        let kanit = try #require(FontPackManifest.bundled.pack("kanit"))
        let generation = registry.generation
        registry.beginExport()
        registry.add(kanit, kanit.file(for: .bold), postScriptName: "Thonburi-Bold")
        #expect(registry.face(of: kanit, weight: .bold) == nil)
        #expect(registry.generation == generation)
        #expect(registry.endExport())
        #expect(registry.face(of: kanit, weight: .bold)?.postScriptName == "Thonburi-Bold")
        #expect(registry.generation > generation)
        #expect(!registry.endExport())
    }

    @Test func vietnameseMovesWholeToAFaceWithItsLetters() {
        let text = "Ngày đầu tiên của chuyến đi"
        for face in [TextOverlayFont.dmSans, .poppins, .syne, .caveat, .dmSerif, .instrumentSerif] {
            let font = TextFont.font(face, weight: .bold, size: 30, text: text)
            #expect(ScriptFontCascade.coversLatin(font, text), "\(face): \(font.fontName)")
            let faces = Set(Self.runs(text, font: font).map(\.font))
            #expect(faces.count == 1, "\(face) mixes \(faces) in one line")
        }
        // A family that has the letters keeps them.
        #expect(TextFont.font(.montserrat, weight: .bold, size: 30, text: text).fontName.hasPrefix("Montserrat"))
        #expect(TextFont.font(.dmSans, weight: .bold, size: 30, text: "Olá, Größe").fontName.hasPrefix("DMSans"))
    }

    @Test func aLibraryFamilyDrawsInTheSystemsFaceOfItsScriptUntilItArrives() {
        let font = TextFont.font(.pack("zenoldmincho"), weight: .bold, size: 30, text: "朝ごはん")
        #expect(font.fontName.hasPrefix("HiraMin"), "\(font.fontName)")
        let kanit = TextFont.font(.pack("kanit"), weight: .bold, size: 30, text: "วันแรก")
        #expect(kanit.fontName == "Thonburi-Bold", "\(kanit.fontName)")
    }

    @Test func captionsTextsAndTheCoverAskForTheSameFace() {
        let text = "Day 1 の朝"
        var spec = CaptionStyleSpec.spec(for: .bold, version: CaptionStyleSpec.currentVersion)
        let caption = CaptionFont.font(spec: spec, size: 40, text: text)
        let overlay = TextFont.font(.montserrat, weight: .heavy, size: 40, text: text)
        let cover = CoverTextLayout.font(CoverFont(.montserrat, weight: .heavy), size: 40, text: text)
        let shapes = [caption, overlay, cover].map { Self.runs(text, font: $0).map(\.font) }
        #expect(shapes[0] == shapes[1] && shapes[1] == shapes[2], "\(shapes)")
        // Asked twice (the preview, then the export), the same faces.
        spec.face = .rubik
        #expect(Self.runs(text, font: CaptionFont.font(spec: spec, size: 40, text: text)).map(\.font)
            == Self.runs(text, font: CaptionFont.font(spec: spec, size: 40, text: text)).map(\.font))
    }

    /// A text with Type wave (letters move one by one), in `face`.
    private func waving(_ words: String, face: TextOverlayFont) throws -> TextEffectLayout {
        var text = TextOverlay(role: .title, look: TypePreset.wave.look(for: .title), preset: .wave, span: TimeSpan(start: 0, end: 4))
        text.text = words
        text.font = face
        let request = try #require(TextOverlayRenderer.effectRequest(for: text, frameWidth: 1080, widthFraction: TextOverlayRenderer.maxWidthFraction))
        return try #require(TextEffectCache.shared.layout(for: request))
    }

    /// A text with `preset`'s effect, laid out for its motion.
    private func effectLayout(_ words: String, preset: TypePreset, face: TextOverlayFont = .montserrat) throws -> TextEffectLayout {
        var text = TextOverlay(role: .title, look: preset.look(for: .title), preset: preset, span: TimeSpan(start: 0, end: 4))
        text.text = words
        text.font = face
        let request = try #require(TextOverlayRenderer.effectRequest(for: text, frameWidth: 1080, widthFraction: TextOverlayRenderer.maxWidthFraction))
        return try #require(TextEffectCache.shared.layout(for: request))
    }

    /// Japanese, Chinese and Thai write no space between words: an effect that moves words moves the language's words, as it
    /// does in English, never the whole line as one piece (measured on an iPhone, `ScriptFontDeviceTests`).
    @Test func wordsWithoutSpacesStillMoveOneByOne() throws {
        let japanese = try effectLayout("朝の習慣を三つ紹介します", preset: .headline)
        #expect(japanese.piecesAreWords)
        #expect(japanese.pieces.count >= 4, "\(japanese.pieces.count) pieces")
        let chinese = try effectLayout("这是改变我早晨的三个习惯", preset: .headline)
        #expect(chinese.pieces.count >= 4, "\(chinese.pieces.count) pieces")
        let thai = try effectLayout("วันแรกของการเดินทาง", preset: .wave)
        #expect(thai.piecesAreWords)
        #expect(thai.pieces.count >= 3, "\(thai.pieces.count) pieces")
        // Spaced writing keeps its words as they were.
        #expect(try effectLayout("Day one of my trip", preset: .headline).pieces.count == 5)
        #expect(try effectLayout("여행 첫날 아침", preset: .headline).pieces.count == 3)
    }

    @Test func effectsMoveJoinedWritingByWordAndChineseCharactersOneByOne() throws {
        // Arabic, Hindi and Thai in a family that lacks them: their face comes from the cascade, and they still move by word.
        for words in ["مرحبا بكم", "नमस्ते दोस्तों", "สวัสดี ทุกคน"] {
            #expect(try waving(words, face: .anton).piecesAreWords, "\(words)")
        }
        // Japanese moves letter by letter, each a whole character, in the style's Japanese face.
        let japanese = try waving("朝ごはん", face: .montserrat)
        #expect(!japanese.piecesAreWords)
        #expect(japanese.pieces.count == 4, "\(japanese.pieces.count)")
    }
}
