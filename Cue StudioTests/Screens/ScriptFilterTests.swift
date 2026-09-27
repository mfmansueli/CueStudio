//
//  ScriptFilterTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptFilter")
struct ScriptFilterTests {
    private let scripts = [
        TestData.script(title: "Café morning", text: "Espresso first.", platform: .tiktok),
        TestData.script(title: "Lamp review", text: "It folds flat.", platform: .reels, folder: "Brand deals"),
        TestData.script(title: "Q&A", text: "Questions about coffee.", platform: .youtube),
    ]

    @Test func allKeepsEverythingInOrder() {
        #expect(ScriptFilter.apply(.all, query: "", to: scripts) == scripts)
    }

    @Test func platformFilter() {
        #expect(ScriptFilter.apply(.platform(.reels), query: "", to: scripts).map(\.title) == ["Lamp review"])
    }

    @Test func folderFilter() {
        #expect(ScriptFilter.apply(.folder("Brand deals"), query: "", to: scripts).map(\.title) == ["Lamp review"])
    }

    @Test func searchMatchesTitleAndTextIgnoringCaseAndAccents() {
        #expect(ScriptFilter.apply(.all, query: "cafe", to: scripts).map(\.title) == ["Café morning"])
        #expect(ScriptFilter.apply(.all, query: "COFFEE", to: scripts).map(\.title) == ["Q&A"])
    }

    @Test func searchCombinesWithTheFilter() {
        #expect(ScriptFilter.apply(.platform(.tiktok), query: "coffee", to: scripts).isEmpty)
    }
}
