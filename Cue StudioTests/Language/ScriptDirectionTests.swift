//
//  ScriptDirectionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("ScriptDirection")
struct ScriptDirectionTests {
    @Test func theScriptsLanguageDecides() {
        #expect(ScriptDirection.isRightToLeft(language: .arabic, text: "Hello"))
        #expect(!ScriptDirection.isRightToLeft(language: .english, text: "مرحبا بكم في قناتي"))
    }

    @Test func autoDetectReadsTheText() {
        #expect(ScriptDirection.isRightToLeft(language: nil, text: "هذه ثلاث عادات غيرت صباحي. أولا، أشرب كوبا من الماء."))
        #expect(!ScriptDirection.isRightToLeft(language: nil, text: "Here are three habits that changed my mornings."))
        #expect(!ScriptDirection.isRightToLeft(language: nil, text: ""))
    }
}
