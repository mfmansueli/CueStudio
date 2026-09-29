//
//  LanguageDetectorTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("LanguageDetector")
struct LanguageDetectorTests {
    @Test func tellsTheLanguageOfAScript() {
        #expect(LanguageDetector.language(in: "Esses são três hábitos que mudaram as minhas manhãs.") == .portugueseBrazil)
        #expect(LanguageDetector.language(in: "Here are three habits that changed my mornings.") == .english)
        #expect(LanguageDetector.language(in: "朝の習慣を三つ紹介します。") == .japanese)
    }

    @Test func cuesDontCount() {
        #expect(LanguageDetector.dominantLanguageCode(in: "[pause] [smile]") == nil)
    }
}
