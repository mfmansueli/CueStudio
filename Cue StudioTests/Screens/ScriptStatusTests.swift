//
//  ScriptStatusTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A script's row on Scripts: ready to record, then the stage of its takes.
@Suite("Script status")
struct ScriptStatusTests {
    private let id = UUID()

    private func take(_ number: Int, isBest: Bool = false, isExported: Bool = false) -> Take {
        var take = TestData.take(scriptID: id, number: number, isBest: isBest)
        take.isExported = isExported
        return take
    }

    @Test func aScriptWithNoTakeIsReadyToRecordWithItsLength() {
        let status = ScriptStatus(takes: [], readSeconds: 20, hasDraft: { _ in false })
        #expect(status.values == ["Ready to record", "0:20"] && status.stage == nil)
    }

    @Test func itsTakesPutItAtTheStageTheTakesTabShows() {
        let one = ScriptStatus(takes: [take(1)], readSeconds: 20, hasDraft: { _ in false })
        #expect(one.values == ["1 take", "Ready"] && one.stage == .ready)
        let several = ScriptStatus(takes: [take(1), take(2), take(3)], readSeconds: 20, hasDraft: { _ in false })
        #expect(several.values == ["3 takes", "To pick"] && several.stage == .pick)
        let shared = ScriptStatus(takes: [take(1, isBest: true, isExported: true), take(2)], readSeconds: 20, hasDraft: { _ in false })
        #expect(shared.stage == .shared)
        let editing = ScriptStatus(takes: [take(1)], readSeconds: 20, hasDraft: { _ in true })
        #expect(editing.stage == .edit)
    }
}
