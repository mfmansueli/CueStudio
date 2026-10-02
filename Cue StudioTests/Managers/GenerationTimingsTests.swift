//
//  GenerationTimingsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("GenerationTimings")
struct GenerationTimingsTests {
    @Test func durationsAreReadInSeconds() {
        #expect(Duration.seconds(2).inSeconds == 2)
        #expect(abs(Duration.milliseconds(1500).inSeconds - 1.5) < 0.0001)
        #expect(Duration.zero.inSeconds == 0)
    }

    @Test func aStructuredDraftHasNoTimings() {
        let script = GeneratedScript(title: "T", text: "Hello.", usedLanguageModel: false)
        #expect(script.timings == nil)
    }

    @Test func timingsKeepTheModelsPhasesApart() {
        let timings = GenerationTimings(prepare: .milliseconds(40), firstResponse: .seconds(3), generation: .seconds(21))
        let script = GeneratedScript(title: "T", text: "Hello.", usedLanguageModel: true, timings: timings)
        #expect(script.timings?.firstResponse == .seconds(3))
        #expect(script.timings?.generation == .seconds(21))
        #expect((script.timings?.prepare.inSeconds ?? 1) < 0.1)
    }
}
