//
//  LogbookServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The Logbook: ideas caught now, shaped later.
@MainActor
@Suite("LogbookService")
struct LogbookServiceTests {
    private func make() -> (LogbookService, TestDefaults) {
        let defaults = TestDefaults()
        return (LogbookService(defaults: defaults.defaults, now: { TestData.now }), defaults)
    }

    @Test func anIdeaIsKeptNewestFirstAndBlankOnesAreNot() {
        let (logbook, defaults) = make()
        defer { defaults.tearDown() }
        #expect(logbook.add("   ") == nil)
        logbook.add("First idea")
        logbook.add("Second idea", spokenSeconds: 14)
        #expect(logbook.entries.map(\.text) == ["Second idea", "First idea"])
        #expect(logbook.entries[0].isSpoken && !logbook.entries[1].isSpoken)
    }

    @Test func aShapedIdeaNoLongerWaits() {
        let (logbook, defaults) = make()
        defer { defaults.tearDown() }
        let entry = logbook.add("Cold showers: myth vs. what helped")
        let id = entry?.id ?? UUID()
        #expect(logbook.waiting.count == 1)
        logbook.markShaped(id, as: UUID())
        #expect(logbook.waiting.isEmpty && logbook.entries.count == 1)
    }

    @Test func theIdeasSurviveARelaunch() {
        let (logbook, defaults) = make()
        defer { defaults.tearDown() }
        let entry = logbook.add("Why I stopped buying coffee out", spokenSeconds: 14)
        logbook.setTopic("niche.finance", of: entry?.id ?? UUID())
        let again = LogbookService(defaults: defaults.defaults)
        #expect(again.entries.count == 1)
        #expect(again.entries[0].topic == "niche.finance" && again.entries[0].spokenSeconds == 14)
    }

    @Test func deletingRemovesIt() {
        let (logbook, defaults) = make()
        defer { defaults.tearDown() }
        let id = logbook.add("Gone soon")?.id ?? UUID()
        logbook.delete(id)
        #expect(logbook.entries.isEmpty)
    }
}
