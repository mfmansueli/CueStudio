//
//  TextShapingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Words drawn on a video keep their writing: no letter spacing where letters join or stack, and capitals as the language
/// writes them (Turkish "İ").
@MainActor
@Suite("Text shaping")
struct TextShapingTests {
    @Test func lettersAreSpacedOnlyWhereTheyStandApart() {
        for joined in ["مرحبا بكم", "नमस्ते दोस्तों", "สวัสดีครับ", "ສະບາຍດີ", "မင်္ဂလာပါ", "សួស្តី", "ހެލޯ"] {
            #expect(!TextShaping.allowsLetterSpacing(in: joined), "\(joined)")
        }
        for apart in ["Comidas de SP", "日本語のテキスト", "안녕하세요", "Привет", "Γειά σου", "İstanbul'da"] {
            #expect(TextShaping.allowsLetterSpacing(in: apart), "\(apart)")
        }
    }

    @Test func labelsAreSpacedOnlyInLanguagesWhoseLettersStandApart() {
        for joined in ["ar", "hi", "th"] {
            #expect(!TextShaping.allowsLetterSpacing(in: Locale.Language(identifier: joined)), "\(joined)")
        }
        for apart in ["en", "pt-BR", "de", "ja", "zh-Hant", "ko", "tr", "vi"] {
            #expect(TextShaping.allowsLetterSpacing(in: Locale.Language(identifier: apart)), "\(apart)")
        }
    }

    @Test func turkishCapitalsKeepTheDot() {
        #expect(TextShaping.uppercased("istanbul'da bir gün nasıl geçer") == "İSTANBUL'DA BİR GÜN NASIL GEÇER")
        #expect(TextShaping.uppercased("five things in istanbul you should see") == "FIVE THINGS IN ISTANBUL YOU SHOULD SEE")
    }

    @Test func aTurkishTextInCapitalsIsDrawnWithTheDot() {
        var text = TextOverlay(role: .title, look: TypePreset.cue.look(for: .title), preset: .cue, span: TimeSpan(start: 0, end: 2))
        text.text = "bugün istanbul'da neler yedim"
        text.isUppercase = true
        #expect(text.displayText == "BUGÜN İSTANBUL'DA NELER YEDİM")
    }

    @Test func aLitWordIsFoundInATurkishLineInCapitals() {
        let words = ["bugün", "istanbul'da", "neler", "yedim"]
        let display = TextShaping.uppercased(words.joined(separator: " "))
        let emphasis = WordEmphasis(words: words, index: 1, style: .color(.yellow), count: 1)
        let range = emphasis.range(in: display, uppercased: true)
        #expect(range.map { (display as NSString).substring(with: $0) } == "İSTANBUL'DA")
    }
}
