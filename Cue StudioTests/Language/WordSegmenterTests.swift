//
//  WordSegmenterTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("WordSegmenter")
struct WordSegmenterTests {
    @Test func textWithSpacesIsLeftAlone() {
        #expect(!WordSegmenter.containsUnspacedScript("Olá, você! Here we go."))
        #expect(!WordSegmenter.containsUnspacedScript("안녕하세요 여러분"))
        #expect(!WordSegmenter.containsUnspacedScript("مرحبا بكم"))
        #expect(WordSegmenter.segments(of: "você").map(\.word) == ["você"])
    }

    @Test func japaneseChineseAndThaiAreSplitIntoWords() {
        #expect(WordSegmenter.containsUnspacedScript("水を飲みます"))
        #expect(WordSegmenter.containsUnspacedScript("喝一杯水"))
        #expect(WordSegmenter.containsUnspacedScript("ดื่มน้ำ"))
        #expect(WordSegmenter.segments(of: "水を一杯飲みます").count > 2)
        #expect(WordSegmenter.segments(of: "我在看手机之前先喝一杯水").count > 4)
        #expect(WordSegmenter.segments(of: "ฉันดื่มน้ำหนึ่งแก้ว").count > 2)
    }

    @Test func segmentsKnowWhereTheyStart() {
        let run = "我喝水"
        for segment in WordSegmenter.segments(of: run) {
            let start = run.index(run.startIndex, offsetBy: segment.offset)
            #expect(run[start...].hasPrefix(segment.word))
        }
    }

    @Test func wordCountsWorkInEveryScript() {
        #expect(WordSegmenter.wordCount(in: "Here are three habits.") == 4)
        #expect(WordSegmenter.wordCount(in: "这是改变我早晨的三个习惯。") > 4)
    }
}
