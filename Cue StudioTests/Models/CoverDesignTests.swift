//
//  CoverDesignTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The v26 cover design: how a title becomes words, which one is highlighted, what "My cover style"
/// keeps, and that covers made before it still open.
@Suite("CoverDesign")
struct CoverDesignTests {
    @Test func aNewDesignIsAHookInAntonWithNothingOnTop() {
        let design = CoverDesign()
        #expect(design.layout == .hook && design.font == .anton && design.effect == .clean)
        #expect(design.elements.isEmpty && design.highlightIndex == 1)
    }

    @Test func theHookDrawsEveryWordAsTyped() {
        let design = CoverDesign()
        let parts = design.words(of: "  5 comidas  de SP ")
        #expect(parts.number == nil)
        #expect(parts.words == ["5", "comidas", "de", "SP"])
    }

    @Test func theNumberLayoutTakesTheFirstNumberOutAndBigAsItsOwn() {
        var design = CoverDesign()
        design.layout = .number
        let parts = design.words(of: "Top 3 morning habits")
        #expect(parts.number == "3")
        #expect(parts.words == ["Top", "morning", "habits"])
        // No number in the title: the big one is 3.
        #expect(design.words(of: "Morning habits").number == "3")
    }

    @Test func theQuestionLayoutEndsTheLastWordWithAQuestionMarkOnce() {
        var design = CoverDesign()
        design.layout = .question
        #expect(design.words(of: "Why you sleep badly").words.last == "badly?")
        #expect(design.words(of: "Why you sleep badly?").words.last == "badly?")
    }

    @Test func theHighlightStaysInsideTheWords() {
        var design = CoverDesign()
        design.highlightIndex = 9
        #expect(design.highlight(in: 3) == 2)
        design.highlightIndex = -4
        #expect(design.highlight(in: 3) == 0)
        #expect(design.highlight(in: 0) == nil)
    }

    @Test func theKickerNamesThePartAndTheFirstWord() {
        var design = CoverDesign()
        design.episode = 7
        #expect(design.kicker(firstWord: "FIVE") == "Part 7 · FIVE")
        #expect(design.episodeLabel == "EP 07")
    }

    @Test func aStyleKeepsTheLookAndNotTheWords() {
        var design = CoverDesign()
        design.layout = .kicker
        design.font = .serif
        design.effect = .dim
        design.elements = [.series, .arrow]
        design.highlightIndex = 3
        let look = design.look
        #expect(look == CoverLook(layout: .kicker, font: .serif, effect: .dim, series: true))

        var other = CoverDesign()
        other.highlightIndex = 2
        other.handle = "maya"
        other.elements = [.badge]
        other.apply(look)
        #expect(other.layout == .kicker && other.font == .serif && other.effect == .dim)
        // The series tag follows the style; the other elements, the word and the handle stay.
        #expect(other.elements == [.badge, .series])
        #expect(other.highlightIndex == 2 && other.handle == "maya")
        var without = other
        without.apply(CoverLook(layout: .hook, font: .anton, effect: .clean, series: false))
        #expect(without.elements == [.badge])
    }

    @Test func onlyThePersonEffectsNeedTheCutout() {
        #expect(CoverEffect.allCases.filter(\.needsPersonMask) == [.lift, .outline])
    }

    @Test func beforeAfterHasNoTitle() {
        #expect(!CoverLayout.beforeAfter.showsTitle)
        #expect(CoverLayout.allCases.filter(\.showsTitle).count == 4)
    }

    @Test func aDesignRoundTripsAndOldCoversHaveNone() throws {
        var cover = VideoCover(source: .frame(3))
        var design = CoverDesign()
        design.layout = .question
        design.elements = [.arrow, .handle]
        cover.design = design
        let decoded = try JSONDecoder().decode(VideoCover.self, from: JSONEncoder().encode(cover))
        #expect(decoded.design == design)

        let old = #"{"source":{"frame":{"_0":2}},"title":"Hi","titleY":0.2,"style":"bold"}"#
        #expect(try JSONDecoder().decode(VideoCover.self, from: Data(old.utf8)).design == nil)
    }
}
