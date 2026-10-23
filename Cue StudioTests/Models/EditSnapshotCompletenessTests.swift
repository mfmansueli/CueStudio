//
//  EditSnapshotCompletenessTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Every part of the edit is either something the creator decides, which an undo step keeps and gives back (`EditSnapshot`,
/// `EditLook`, `TakeEdit.apply`), or something listening found, which undo leaves as it is. A part added to `TakeEdit` without
/// being one or the other fails here, so Undo can never quietly drop or freeze a new setting.
@MainActor
@Suite("Undo keeps every decision")
struct EditSnapshotCompletenessTests {
    /// What listening found: never an undo step (`QuickEditViewModel.updateFindings`).
    static let findings: Set<String> = ["cleanUpAnalyzed", "cleanUpAnalyzedSources", "captionTranscript", "sourceTranscripts"]

    @Test func everyPartIsChangedHere() {
        let blank = Self.parts(of: Self.blank())
        for (part, value) in Self.parts(of: Self.everything()) {
            #expect(value != blank[part], "\(part) keeps its starting value in everything(): give it another one")
        }
    }

    @Test func undoGivesBackEveryDecisionAndLeavesWhatWasFound() {
        let everything = Self.everything()
        var restored = Self.blank()
        restored.apply(EditSnapshot(everything))
        let wanted = Self.parts(of: everything)
        let blank = Self.parts(of: Self.blank())
        let back = Self.parts(of: restored)
        for (part, value) in wanted {
            if Self.findings.contains(part) {
                #expect(back[part] == blank[part], "\(part) is found by listening: an undo step leaves it")
            } else {
                #expect(back[part] == value, "\(part) isn't given back by an undo step: add it to EditSnapshot (or EditLook) and TakeEdit.apply")
            }
        }
    }

    @Test func aDraftsUndoStepsReadBackWhole() throws {
        let step = EditSnapshot(Self.everything())
        let read = try JSONDecoder().decode(EditSnapshot.self, from: JSONEncoder().encode(step))
        #expect(read == step)
    }

    @Test func aStepSavedBeforeLockAndLanguageLeavesThemAsTheyAre() throws {
        var saved = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(EditSnapshot(Self.blank()))) as? [String: Any])
        for key in ["lockedLayers", "captionLanguage", "captionLanguageKnown"] { saved[key] = nil }
        let old = try JSONDecoder().decode(EditSnapshot.self, from: JSONSerialization.data(withJSONObject: saved))
        var edit = Self.blank()
        let locked = UUID()
        edit.lockedLayers = [locked]
        edit.captionLanguage = .spanish
        edit.apply(old)
        #expect(edit.lockedLayers == [locked])
        #expect(edit.captionLanguage == .spanish)
    }

    // MARK: - Helpers

    private static func blank() -> TakeEdit { EditFixtures.blank() }

    private static func everything() -> TakeEdit { EditFixtures.everything() }

    /// The stored parts of an edit, by name.
    private static func parts(of edit: TakeEdit) -> [String: AnyHashable] {
        var parts: [String: AnyHashable] = [:]
        for child in Mirror(reflecting: edit).children {
            guard let label = child.label else { continue }
            parts[label] = child.value as? AnyHashable
        }
        return parts
    }
}
