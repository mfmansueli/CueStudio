//
//  EyeContactSettingsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Eye Contact's setting in the recipe: off unless turned on, read safely from edits made before it, kept by undo (Off included).
@Suite("EyeContactSettings")
struct EyeContactSettingsTests {
    private func edit() -> TakeEdit { TakeEdit(sourceDuration: 30, aspect: .vertical) }

    @Test func anEditSavedBeforeHasItOff() throws {
        var saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(edit())) as? [String: Any] ?? [:]
        saved.removeValue(forKey: "eyeContact")
        let read = try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: saved))
        #expect(read.eyeContact == nil)
    }

    @Test func aNewEditKeepsItsStrength() throws {
        var made = edit()
        made.eyeContact = EyeContactSettings(strength: 0.85)
        let read = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(made))
        #expect(read.eyeContact == EyeContactSettings(strength: 0.85))
        #expect(read.eyeContact?.engine == EyeContactSettings.currentEngine)
    }

    @Test func aDamagedSettingReadsAsOffAndNeverBreaksTheEdit() throws {
        var saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(edit())) as? [String: Any] ?? [:]
        saved["eyeContact"] = "nonsense"
        let read = try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: saved))
        #expect(read.eyeContact == nil)
    }

    @Test func strengthStaysInItsRange() throws {
        #expect(EyeContactSettings(strength: 5).strength == 1)
        #expect(EyeContactSettings(strength: 0).strength == EyeContactSettings.strengthRange.lowerBound)
        #expect(EyeContactSettings(strength: .nan).strength == EyeContactSettings.defaultStrength)
        let data = Data(#"{"strength": 9, "engine": 7}"#.utf8)
        let read = try JSONDecoder().decode(EyeContactSettings.self, from: data)
        #expect(read.strength == 1)
        #expect(read.engine == EyeContactSettings.currentEngine)
    }

    @Test func undoStepsKeepOnAndOff() {
        var on = edit()
        on.eyeContact = EyeContactSettings(strength: 0.4)
        let stepWithIt = EditLook(on)
        var later = edit()
        stepWithIt.apply(to: &later)
        #expect(later.eyeContact == EyeContactSettings(strength: 0.4))
        // Back to a step taken while it was off turns it off.
        let stepWithout = EditLook(edit())
        stepWithout.apply(to: &later)
        #expect(later.eyeContact == nil)
    }

    @Test func aStepSavedBeforeEyeContactLeavesIt() throws {
        var on = edit()
        on.eyeContact = EyeContactSettings()
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(EditLook(edit()))) as? [String: Any] ?? [:]
        old.removeValue(forKey: "eyeContact")
        old.removeValue(forKey: "eyeContactKnown")
        let step = try JSONDecoder().decode(EditLook.self, from: JSONSerialization.data(withJSONObject: old))
        step.apply(to: &on)
        #expect(on.eyeContact == EyeContactSettings())
    }
}
