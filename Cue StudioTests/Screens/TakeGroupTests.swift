//
//  TakeGroupTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("TakeGroup")
struct TakeGroupTests {
    @Test func groupsByScriptNewestFirst() {
        let scriptA = UUID(), scriptB = UUID()
        let now = TestData.now
        let takes = [
            TestData.take(scriptID: scriptA, title: "A", number: 1, recordedAt: now.addingTimeInterval(-300)),
            TestData.take(scriptID: scriptB, title: "B", number: 1, recordedAt: now.addingTimeInterval(-400)),
            TestData.take(scriptID: nil, title: "Freestyle recording", number: 1, recordedAt: now.addingTimeInterval(-100)),
            TestData.take(scriptID: scriptA, title: "A", number: 2, recordedAt: now),
        ]
        let groups = TakeGroup.groups(from: takes)
        #expect(groups.map(\.title) == ["A", "Freestyle recordings", "B"])
        #expect(groups[0].takes.map(\.number) == [2, 1])
    }

    @Test func noTakesNoGroups() {
        #expect(TakeGroup.groups(from: []).isEmpty)
    }
}
