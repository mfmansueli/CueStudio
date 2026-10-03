//
//  CaptionCollectionRendererTests.swift
//  Cue StudioTests
//

import CoreImage
import CoreText
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

@MainActor
@Suite("Caption collection")
struct CaptionCollectionRendererTests {
    private let frame = CGSize(width: 1080, height: 1920)
    private let words = ["Sua", "ideia", "merece", "ganhar", "vida."]

    private var cue: CaptionCue {
        CaptionCue(words: words.enumerated().map { index, word in
            CaptionWord(text: word, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.4)
        })
    }

    @Test func theCatalogOffersTheCompletePresetsAndKeepsCleanForSavedEdits() {
        #expect(CaptionTheme.catalog == [.cue, .educational, .interview, .impact, .pop, .editorial])
        #expect(Set(CaptionTheme.allCases) == Set(CaptionTheme.catalog + [.clean]))
        #expect(CaptionSettings().theme == .cue)
        #expect(!CaptionSettings(theme: .clean).followsWords && !CaptionSettings(theme: .interview).followsWords)
        #expect(CaptionSettings(theme: .educational).followsWords)
    }

    @Test(arguments: CaptionTheme.allCases)
    func fontsAreBundledAndEveryActiveWordKeepsItsLayout(_ theme: CaptionTheme) throws {
        let settings = CaptionSettings(theme: theme)
        let font = CaptionFont.font(spec: settings.spec, size: 26, text: cue.text)
        let names: [CaptionTheme: String] = [
            .cue: "SpaceGrotesk", .impact: "Anton", .clean: "Inter", .pop: "Poppins", .editorial: "DMSerif",
            .educational: "Manrope", .interview: "Inter",
        ]
        #expect(font.fontName.contains(names[theme] ?? "missing"))
        if [.cue, .clean, .educational, .interview].contains(theme) {
            let axes = try #require(CTFontCopyVariation(font as CTFont) as? [NSNumber: NSNumber])
            #expect(axes[0x77676874]?.doubleValue == settings.spec.fontWeight)
        }
        let plain = try #require(CaptionCollectionRenderer.image(cue.text, settings: settings, frame: frame))
        let states = CaptionCollectionRenderer.overlays([cue], settings: settings, position: .bottom, frame: frame)
        #expect(Set(states.map(\.origin.x)).count == 1)
        #expect(Set(states.map(\.origin.y)).count == 1)
        #expect(Set(states.map(\.size.width)).count == 1)
        #expect(Set(states.map(\.size.height)).count == 1)
        for index in words.indices {
            let emphasis = WordEmphasis(words: words, index: index, style: .color(.yellow))
            let image = try #require(CaptionCollectionRenderer.image(cue.text, settings: settings, frame: frame, emphasis: emphasis))
            #expect(image.size == plain.size)
        }
        let output = URL.temporaryDirectory.appending(path: "caption-validation", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let emphasis = theme == .clean ? nil : WordEmphasis(words: words, index: 2, style: .color(.yellow))
        let sample = try #require(CaptionCollectionRenderer.image(cue.text, settings: settings, frame: frame, emphasis: emphasis))
        try #require(sample.pngData()).write(to: output.appending(path: "\(theme.rawValue).png"))
        Attachment.record(try #require(sample.pngData()), named: "\(theme.rawValue).png")
    }

    @Test func unknownWordTimingStillFollowsTheStyleByAnApproximation() {
        var estimated = cue
        estimated.words[1].isEstimated = true
        let settings = CaptionSettings()
        let states = CaptionCollectionRenderer.overlays([estimated], settings: settings, position: .bottom, frame: frame)
        #expect(states.count == words.count)
        #expect(states.allSatisfy { $0.lazyText?.emphasis != nil })
    }

    @Test func aLineTypedWithStraySpacesOrWrittenFromScratchKeepsTheEffects() {
        let settings = CaptionSettings()
        var typed = CaptionRevision.retimed(cue, text: "Sua  ideia merece ganhar vida. ")
        // Every word still lights once, in order; the pauses between measured words stay plain.
        let lit = CaptionCollectionRenderer.overlays([typed], settings: settings, position: .bottom, frame: frame)
            .compactMap { $0.lazyText?.emphasis?.index }
        #expect(lit == Array(words.indices))
        typed = CaptionCue(text: "Brand new line", start: 1, end: 3, origin: .manual)
        let states = CaptionCollectionRenderer.overlays([typed], settings: settings, position: .bottom, frame: frame)
        #expect(states.count == 3)
        #expect(states.allSatisfy { $0.lazyText?.emphasis != nil })
    }

    @Test func aCorrectedLineStillLightsItsWordsOneByOne() {
        let settings = CaptionSettings()
        let original = CaptionCollectionRenderer.overlays([cue], settings: settings, position: .bottom, frame: frame)
        for text in ["Sua nova ideia merece ganhar vida.", "Sua ideia merece vida.", "Tua ideia merece ganhar vida."] {
            let revised = CaptionRevision.retimed(cue, text: text)
            #expect(!revised.needsTimingReview)
            #expect(revised.hasWordTiming)
            let states = CaptionCollectionRenderer.overlays([revised], settings: settings, position: .bottom, frame: frame)
            #expect(states.count > 1)
            #expect(states.contains { $0.lazyText?.emphasis != nil })
        }
        #expect(original.count > 1)
    }

    @Test func gapsNeverPretendAWordIsBeingSpoken() {
        let states = CaptionCollectionRenderer.overlays([cue], settings: CaptionSettings(), position: .bottom, frame: frame)
        #expect(states.first { $0.span?.contains(0.45) == true }?.lazyText?.emphasis == nil)
        #expect(states.first { $0.span?.contains(0.55) == true }?.lazyText?.emphasis?.index == 1)
    }

    @Test(arguments: CaptionTheme.allCases)
    func accentsAndAllSupportedScriptsRenderLocally(_ theme: CaptionTheme) throws {
        let samples = [
            "Your idea deserves life.", "Tu idea merece vivir.", "Votre idée mérite de vivre.", "La tua idea merita vita.", "Ide Anda layak hidup.",
            "Ação, coração, você, três.", "Übermäßig groß", "İstanbul güzel", "Ý tưởng của bạn", "今日は晴れです。", "你的想法值得实现。",
            "당신의 아이디어", "आपका विचार", "فكرتك تستحق الحياة", "ความคิดของคุณ",
        ]
        for sample in samples {
            let font = CaptionFont.font(spec: CaptionSettings(theme: theme).spec, size: 26, text: sample)
            #expect(font.pointSize == 26)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: sample, attributes: [.font: font]))
            for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
                var glyphs = [CGGlyph](repeating: 0, count: CTRunGetGlyphCount(run))
                CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
                #expect(!glyphs.contains(0), "Missing glyphs in \(theme.rawValue): \(sample)")
            }
            let image = try #require(CaptionCollectionRenderer.image(sample, settings: CaptionSettings(theme: theme), frame: frame))
            #expect(image.size.height > 0)
        }
    }

    @Test(arguments: CaptionTheme.allCases)
    func positioningAndMaximumSizeStayInsideSafeMargins(_ theme: CaptionTheme) {
        for size in [CGSize(width: 1080, height: 1920), CGSize(width: 1920, height: 1080), CGSize(width: 1080, height: 1080)] {
            var settings = CaptionSettings(theme: theme)
            settings.sizeScale = 1.5
            settings.center = OverlayPoint(x: 0.99, y: 0.99)
            let safe = CaptionCollectionRenderer.contentRect(settings, frame: size).insetBy(dx: -1, dy: -1)
            let overlays = CaptionCollectionRenderer.overlays([cue], settings: settings, position: .bottom, frame: size)
            #expect(!overlays.isEmpty)
            for overlay in overlays {
                let rect = CGRect(x: overlay.origin.x, y: size.height - overlay.origin.y - overlay.size.height,
                                  width: overlay.size.width, height: overlay.size.height)
                #expect(safe.contains(rect))
            }
        }
    }

    @Test func settingsAndLegacyLooksSurviveSaving() throws {
        var edit = TakeEdit(sourceDuration: 5, aspect: .portrait)
        edit.captionCollection = CaptionSettings(theme: .editorial)
        edit.captionCollection?.sizeScale = 1.2
        edit.captionCollection?.accent = .lime
        edit.captionCollection?.center = OverlayPoint(x: 0.4, y: 0.6)
        edit.captions = [CaptionRevision.retimed(cue, text: "Sua ideia merece ganhar VIDA.")]
        let decoded = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(edit))
        #expect(decoded == edit)
        let snapshot = try JSONDecoder().decode(EditSnapshot.self, from: JSONEncoder().encode(EditSnapshot(edit)))
        #expect(snapshot.captionCollection == edit.captionCollection)
        let legacy = try JSONDecoder().decode(TakeEdit.self, from: Data(#"{"sourceDuration":5,"aspect":"9:16","captionStyle":"classic"}"#.utf8))
        #expect(legacy.captionCollection == nil)
        #expect(legacy.captionStyle == .classic)
    }
}
