//
//  CaptionStyleSpecTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Caption presets as complete recipes. The first five keep their exact numbers in every edit saved
/// with them; new looks use the complete ones, each with its own font, weight, size, outline or
/// shadow, color, spacing, line breaking and way of showing words.
@MainActor
@Suite("Caption style recipes")
struct CaptionStyleSpecTests {
    private let frame = CGSize(width: 1080, height: 1920)
    private let words = ["Sua", "ideia", "merece", "ganhar", "vida."]

    private var cue: CaptionCue {
        CaptionCue(words: words.enumerated().map { index, word in
            CaptionWord(text: word, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.4)
        })
    }

    // MARK: - The first reading

    @Test func theFirstFiveKeepTheirExactNumbers() {
        func first(_ theme: CaptionTheme) -> CaptionStyleSpec { CaptionStyleSpec.spec(for: theme, version: 1) }
        let cue = first(.cue)
        #expect(cue.fontName == "SpaceGrotesk-Light" && cue.fontWeight == 700 && cue.baseSize == 26 && cue.highlightsWithBox)
        #expect(cue.shadow == .init(opacity: 0.45, blur: 3, offsetY: 1) && cue.plate == .none && cue.outline == nil)
        let impact = first(.impact)
        #expect(impact.fontName == "Anton-Regular" && impact.baseSize == 30 && impact.uppercase)
        #expect(impact.outline == .init(width: 6, color: .black) && impact.shadow == nil && impact.defaultAccent == .lime)
        let clean = first(.clean)
        #expect(clean.fontName == "Inter-Regular" && clean.fontWeight == 600 && clean.baseSize == 25 && clean.animation == .line)
        #expect(clean.shadow == .init(opacity: 0.45, blur: 3, offsetY: 1))
        let pop = first(.pop)
        #expect(pop.fontName == "Poppins-ExtraBold" && pop.fontWeight == 800 && pop.lineSpacing == 5)
        #expect(pop.plate == .perLine(color: .init(red: 0.39, green: 0.16, blue: 0.77), radius: 9, insetX: 10, insetY: 2))
        let editorial = first(.editorial)
        #expect(editorial.fontName == "Manrope-Regular" && editorial.baseSize == 24 && editorial.defaultAccent == .peach)
        #expect(editorial.plate == .block(color: .init(red: 0, green: 0, blue: 0, alpha: 0.66), radius: 5, insetX: 10, insetY: 4))
        #expect(editorial.textColor == .init(red: 0.96, green: 0.96, blue: 0.96))
        // What they all shared.
        for theme in [CaptionTheme.cue, .impact, .clean, .pop, .editorial] {
            let spec = first(theme)
            #expect(spec.widthFraction == 0.8 && spec.balanceFromWords == 4 && spec.balanceRatio == 1.7 && spec.maxLines == 3)
            #expect(spec.entry == .none && spec.tracking == 0)
        }
    }

    @Test func cueAndCleanAreTheSameInBothReadings() {
        for theme in [CaptionTheme.cue, .clean] {
            #expect(CaptionStyleSpec.spec(for: theme, version: 1) == CaptionStyleSpec.spec(for: theme, version: 2))
        }
    }

    @Test func settingsSavedBeforeTheCompletePresetsKeepTheirLook() throws {
        var settings = CaptionSettings(theme: .editorial)
        #expect(settings.styleVersion == CaptionStyleSpec.currentVersion)
        // Saved by a build without the version: the key is gone.
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        object.removeValue(forKey: "styleVersion")
        settings = try JSONDecoder().decode(CaptionSettings.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(settings.styleVersion == nil)
        #expect(settings.spec == CaptionStyleSpec.spec(for: .editorial, version: 1))
        #expect(settings.spec.fontName == "Manrope-Regular")
        // A new look of the same preset is the complete one.
        #expect(CaptionSettings(theme: .editorial).spec.fontName == "DMSerifDisplay-Regular")
        #expect(settings.highlightColor == .peach)
    }

    // MARK: - The complete presets

    @Test func everyPresetHasItsOwnFontSizeAndRecipe() {
        let specs = CaptionTheme.catalog.map { CaptionStyleSpec.spec(for: $0, version: 2) }
        for spec in specs {
            #expect(UIFont(name: spec.fontName, size: 20) != nil, "\(spec.fontName) isn't bundled")
            #expect((22...31).contains(spec.baseSize))
            #expect((0.6...0.9).contains(spec.widthFraction) && spec.maxLines >= 2)
        }
        // No two presets are a font swap of each other.
        for (index, first) in specs.enumerated() {
            for second in specs[(index + 1)...] {
                var differences = 0
                differences += first.fontName == second.fontName ? 0 : 1
                differences += first.plate == second.plate ? 0 : 1
                differences += first.outline == second.outline ? 0 : 1
                differences += first.shadow == second.shadow ? 0 : 1
                differences += first.entry == second.entry ? 0 : 1
                differences += first.animation == second.animation ? 0 : 1
                differences += first.widthFraction == second.widthFraction ? 0 : 1
                differences += first.tracking == second.tracking ? 0 : 1
                #expect(differences >= 3, "\(first.fontName) and \(second.fontName) differ only a little")
            }
        }
    }

    @Test func educationalIsClearToReadWithADiscreteHighlight() {
        let spec = CaptionStyleSpec.spec(for: .educational, version: 2)
        guard case .block(let color, _, _, _) = spec.plate else { Issue.record("no plate"); return }
        #expect(color.alpha >= 0.5)
        #expect(spec.animation == .highlight && !spec.highlightsWithBox && spec.defaultAccent == .yellow)
        #expect(spec.widthFraction >= 0.8 && spec.outline == nil)
    }

    @Test func interviewIsSoberAndSteady() {
        let spec = CaptionStyleSpec.spec(for: .interview, version: 2)
        #expect(spec.animation == .line && !spec.animation.followsWords)
        #expect(spec.entry.popDuration == 0 && spec.entry.fade > 0 && spec.entry.fade <= 0.15)
        #expect(spec.fontWeight <= 600 && spec.maxLines == 2 && spec.outline == nil)
    }

    @Test func impactIsStrongWithAReadableOutlineAndShortLines() {
        let impact = CaptionStyleSpec.spec(for: .impact, version: 2)
        let first = CaptionStyleSpec.spec(for: .impact, version: 1)
        #expect(impact.uppercase && (impact.outline?.width ?? 0) >= 7 && impact.shadow != nil)
        #expect(impact.widthFraction < first.widthFraction && impact.maxLines == 2 && impact.balanceFromWords < first.balanceFromWords)
        #expect(impact.entry.popScale < 1 && impact.entry.popDuration <= 0.12)
    }

    @Test func popIsExpressiveButStaysReadable() {
        let pop = CaptionStyleSpec.spec(for: .pop, version: 2)
        #expect(pop.fontWeight >= 800 && pop.entry.popScale < 1 && pop.entry.popDuration >= 0.15)
        guard case .perLine(let color, _, _, _) = pop.plate else { Issue.record("no plate"); return }
        // White on the plate: dark enough for 4.5:1 (relative luminance of the sRGB color).
        func linear(_ value: Double) -> Double { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
        #expect(1.05 / (luminance + 0.05) >= 4.5)
    }

    @Test func editorialIsElegantWithOpenSpacing() {
        let editorial = CaptionStyleSpec.spec(for: .editorial, version: 2)
        let first = CaptionStyleSpec.spec(for: .editorial, version: 1)
        #expect(editorial.tracking > 0 && editorial.lineSpacing > first.lineSpacing && editorial.entry.fade >= 0.15)
        #expect(editorial.fontName == "DMSerifDisplay-Regular")
    }

    // MARK: - Writing systems

    @Test func letterSpacingIsLeftOutWhereLettersJoinOrStack() {
        for text in ["فكرتك تستحق الحياة", "आपका विचार", "ความคิดของคุณ"] {
            #expect(!CaptionFont.allowsTracking(in: text), "\(text)")
        }
        for text in ["Your idea", "Ação, você, três", "İstanbul güzel", "Ý tưởng", "今日は晴れです", "你的想法", "당신의 아이디어", "Ваша идея"] {
            #expect(CaptionFont.allowsTracking(in: text), "\(text)")
        }
    }

    @Test func spacedPresetsRenderEveryWritingSystem() throws {
        for sample in ["فكرتك تستحق الحياة", "आपका विचार", "ความคิดของคุณ", "今日は晴れです。", "Ý tưởng của bạn"] {
            for theme in [CaptionTheme.editorial, .interview] {
                let image = try #require(CaptionCollectionRenderer.image(sample, settings: CaptionSettings(theme: theme), frame: frame))
                #expect(image.size.width > 0 && image.size.width <= frame.width)
            }
        }
    }

    // MARK: - Coming in

    @Test func aLineLandsWithALittleOvershootAndSettles() {
        #expect(abs(FrameOverlay.popScale(from: 0.86, elapsed: 0, duration: 0.18) - 0.86) < 0.000_000_1)
        #expect(FrameOverlay.popScale(from: 0.86, elapsed: 0.18, duration: 0.18) == 1)
        #expect(FrameOverlay.popScale(from: 0.86, elapsed: 5, duration: 0.18) == 1)
        let middle = (1...17).map { FrameOverlay.popScale(from: 0.86, elapsed: Double($0) * 0.01, duration: 0.18) }
        #expect(middle.max()! > 1 && middle.max()! < 1.05)
        #expect(middle.allSatisfy { $0 > 0.86 })
    }

    @Test func onlyTheFirstStateOfALinePopsAndTheLastFadesOut() throws {
        let pop = CaptionCollectionRenderer.overlays([cue], settings: CaptionSettings(theme: .pop), position: .bottom, frame: frame)
        #expect(pop.count > 1)
        #expect(pop.first?.popScale == 0.86 && pop.first?.popDuration == 0.18)
        #expect(pop.dropFirst().allSatisfy { $0.popDuration == 0 && $0.fadeIn == 0 })
        let editorial = CaptionCollectionRenderer.overlays([cue], settings: CaptionSettings(theme: .editorial), position: .bottom, frame: frame)
        #expect(editorial.first?.fadeIn == 0.2 && editorial.last?.fadeOut == 0.2)
        #expect(editorial.dropFirst().dropLast().allSatisfy { $0.fadeIn == 0 && $0.fadeOut == 0 })
        let interview = CaptionCollectionRenderer.overlays([cue], settings: CaptionSettings(theme: .interview), position: .bottom, frame: frame)
        #expect(interview.count == 1 && interview[0].fadeIn == 0.1 && interview[0].fadeOut == 0.1)
        // Cue comes in as it always did.
        let plain = CaptionCollectionRenderer.overlays([cue], settings: CaptionSettings(theme: .cue), position: .bottom, frame: frame)
        #expect(plain.allSatisfy { $0.fadeIn == 0 && $0.fadeOut == 0 && $0.popDuration == 0 })
    }

    @Test func aSavedEditWithTheFirstReadingComesInAsItAlwaysDid() throws {
        var settings = CaptionSettings(theme: .pop)
        settings.styleVersion = nil
        let overlays = CaptionCollectionRenderer.overlays([cue], settings: settings, position: .bottom, frame: frame)
        #expect(overlays.allSatisfy { $0.fadeIn == 0 && $0.fadeOut == 0 && $0.popDuration == 0 })
    }

    // MARK: - Layout

    @Test func theLinesStayWithinWhatEachPresetAllows() throws {
        let long = "Sua ideia merece ganhar vida hoje mesmo, com calma e sem pressa nenhuma"
        for theme in CaptionTheme.catalog {
            let settings = CaptionSettings(theme: theme)
            let image = try #require(CaptionCollectionRenderer.image(long, settings: settings, frame: frame))
            let safe = CaptionCollectionRenderer.contentRect(settings, frame: frame)
            #expect(image.size.width <= min(frame.width * settings.spec.widthFraction, safe.width) + 28 * frame.width / 402 + 1)
            #expect(image.size.height <= safe.height)
        }
    }

    @Test func aWiderPresetBreaksIntoFewerLinesThanANarrowOne() throws {
        let text = "Sua ideia merece ganhar vida hoje mesmo"
        let educational = try #require(CaptionCollectionRenderer.image(text, settings: CaptionSettings(theme: .educational), frame: frame))
        let impact = try #require(CaptionCollectionRenderer.image(text, settings: CaptionSettings(theme: .impact), frame: frame))
        // Impact is condensed capitals in two short lines: narrower than Educational's reading column.
        #expect(impact.size.width < educational.size.width)
    }
}
