//
//  MultilingualVoiceFollowTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Voice Following's matching in every script: the same tokens and tracker as English and
/// Portuguese, with words found by dictionary where a language has no spaces.
@Suite("Voice Following in other languages")
struct MultilingualVoiceFollowTests {
    private func follow(_ script: String, hearing transcripts: [String]) -> (position: Int, count: Int) {
        let words = ScriptWords(text: script)
        var tracker = ScriptSpeechTracker(words: words.tokens)
        for transcript in transcripts { tracker.hear(transcript) }
        return (tracker.position, words.count)
    }

    /// The whole script heard a few words at a time, the way recognition reports it.
    private func growing(_ text: String, by step: Int = 3) -> [String] {
        let tokens = ScriptWords.tokens(in: text)
        return stride(from: step, through: tokens.count + step - 1, by: step).map { tokens.prefix($0).joined(separator: " ") }
    }

    @Test func englishAndPortugueseTokensAreUnchanged() {
        #expect(ScriptWords.tokens(in: "Olá, VOCÊ! Don't stop—now.") == ["ola", "voce", "dont", "stop", "now"])
        #expect(ScriptWords(text: "Esses são três hábitos.").tokens == ["esses", "sao", "tres", "habitos"])
    }

    @Test(arguments: [
        "朝の習慣を三つ紹介します。まず、スマホを見る前に水を一杯飲みます。",
        "这是改变我早晨的三个习惯。第一，我在看手机之前先喝一杯水。",
        "นี่คือสามนิสัยที่เปลี่ยนตอนเช้าของฉัน อย่างแรก ฉันดื่มน้ำหนึ่งแก้วก่อนจับโทรศัพท์",
    ])
    func languagesWithoutSpacesAreReadWordByWord(script: String) {
        let words = ScriptWords(text: script)
        #expect(words.count > 8)
        // Recognition writes the words without spaces too; they split the same way.
        let heard = [String(script.prefix(script.count / 2)), script]
        let result = follow(script, hearing: heard)
        #expect(result.position == result.count)
    }

    @Test(arguments: [
        "Estos son tres hábitos que cambiaron mis mañanas. Primero, bebo un vaso de agua.",
        "Das sind drei Gewohnheiten, die meine Morgen verändert haben. Erstens trinke ich Wasser.",
        "제 아침을 바꾼 세 가지 습관을 소개할게요. 먼저 물을 한 잔 마셔요.",
        "ये तीन आदतें हैं जिन्होंने मेरी सुबह बदल दी। पहली, मैं पानी पीती हूँ।",
        "هذه ثلاث عادات غيرت صباحي. أولا، أشرب كوبا من الماء قبل أن ألمس هاتفي.",
        "Sabahlarımı değiştiren üç alışkanlık var. İlk olarak bir bardak su içiyorum.",
        "Đây là ba thói quen đã thay đổi buổi sáng của tôi. Đầu tiên, tôi uống nước.",
    ])
    func languagesWithSpacesFollowAsBefore(script: String) {
        let result = follow(script, hearing: growing(script))
        #expect(result.position == result.count)
    }

    /// Recognition often drops accents and marks; the script's are ignored the same way.
    @Test func accentsDontGetInTheWay() {
        let result = follow("Đây là ba thói quen", hearing: ["day la ba thoi quen"])
        #expect(result.position == result.count)
    }

    @Test func readingTimeCountsWordsInEveryLanguage() {
        #expect(ReadTime.wordCount(in: "Here are three habits [pause] that changed.") == 6)
        let japanese = ReadTime.wordCount(in: "朝の習慣を三つ紹介します。")
        #expect(japanese > 3)
        #expect(ReadTime.seconds(for: "朝の習慣を三つ紹介します。") > 0)
    }
}
