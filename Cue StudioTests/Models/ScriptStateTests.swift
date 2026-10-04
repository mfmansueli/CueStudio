//
//  ScriptStateTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// 04 · F2: RECORDED if there is ≥ 1 take · otherwise READY if `isFinished` · otherwise DRAFT.
@Suite("ScriptState")
struct ScriptStateTests {
    @Test(arguments: [
        (true, 0, ScriptState.ready), (false, 0, .draft), (true, 1, .recorded), (false, 1, .recorded), (false, 4, .recorded),
    ])
    func theSingleRule(isFinished: Bool, takes: Int, expected: ScriptState) {
        #expect(ScriptState.resolve(isFinished: isFinished, takeCount: takes) == expected)
    }

    @Test func letsCueAndAFormatThatTheAIWroteStartReady() {
        #expect(Script(title: "A", text: "Words", platform: .tiktok, isFinished: true).state(takeCount: 0) == .ready)
    }

    @Test func writeItMyselfAndStartFromAFormatStartAsDrafts() {
        #expect(Script(title: "", text: "", platform: .tiktok).state(takeCount: 0) == .draft)
        #expect(Script(title: "T", text: "Hook\n\n\n", platform: .tiktok, isFinished: false).state(takeCount: 0) == .draft)
    }

    @Test func editingAfterRecordingStaysRecorded() {
        var script = Script(title: "A", text: "Words", platform: .tiktok, isFinished: true)
        script.isFinished = false
        #expect(script.state(takeCount: 2) == .recorded)
    }

    @Test func theStripSaysChangedSinceTakeOnlyWhenTheScriptMovedOn() {
        var script = Script(title: "A", text: "Words", platform: .tiktok)
        #expect(!script.changedSince(latestTakeVersion: 1))
        script.version = 2
        #expect(script.changedSince(latestTakeVersion: 1))
        #expect(!script.changedSince(latestTakeVersion: nil))
    }

    @Test func aDuplicateInheritsTheStateOfItsOriginal() async {
        await MainActor.run {
            let service = ScriptLibraryService(repository: FakeScriptRepository())
            let original = service.create(title: "A", text: "Words", platform: .tiktok, isFinished: false)
            let copy = service.duplicate([original.id]).first
            #expect(copy?.isFinished == false)
            #expect(copy?.title.hasSuffix("(copy)") == true || copy?.title.contains("copy") == true)
        }
    }

    @Test func groupsAreOrderedReadyDraftsRecorded() {
        #expect(ScriptState.allCases.sorted { $0.sortOrder < $1.sortOrder } == [.ready, .draft, .recorded])
    }
}
