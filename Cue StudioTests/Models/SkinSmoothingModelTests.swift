//
//  SkinSmoothingModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Skin Smoothing in the look settings: off by default, saved with the edit (older edits have none), a clip can set its own, and Compare, undo and
/// Reset treat it like every other dial.
@Suite("Skin Smoothing in the look")
struct SkinSmoothingModelTests {
    private func edit(duration: TimeInterval = 20) -> TakeEdit {
        TakeEdit(sourceDuration: duration, aspect: .portrait)
    }

    /// `value` as JSON without the keys in `removing`: what an older build would have saved.
    private func json<T: Encodable>(_ value: T, removing keys: [String]) throws -> Data {
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
        for key in keys { object.removeValue(forKey: key) }
        return try JSONSerialization.data(withJSONObject: object)
    }

    // MARK: - Off by default

    @Test func everythingStartsOff() {
        #expect(edit().skinSmoothing == 0)
        #expect(LookSettings().skinSmoothing == 0)
        #expect(LookSettings(edit()).skinSmoothing == 0)
        #expect(ClipLook().skinSmoothing == nil)
        #expect(!edit().hasPictureLook)
        #expect(LookSettings().isNeutral)
    }

    @Test func aTakeWithSmoothingIsNotNeutralAndIsADifferentEdit() {
        var take = edit()
        take.skinSmoothing = 30
        #expect(!LookSettings(take).isNeutral)
        #expect(take.hasPictureLook)
        #expect(take.differs(from: .portrait))
        #expect(!edit().differs(from: .portrait))
    }

    // MARK: - Saved edits

    @Test func theValueIsSavedWithTheEdit() throws {
        var take = edit()
        take.skinSmoothing = 35
        let decoded = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(take))
        #expect(decoded.skinSmoothing == 35)
        #expect(decoded == take)
    }

    @Test func anEditSavedBeforeSkinSmoothingHasNone() throws {
        var take = edit()
        take.exposure = 20
        take.filter = .studio
        take.skinSmoothing = 60
        let older = try json(take, removing: ["skinSmoothing"])
        let decoded = try JSONDecoder().decode(TakeEdit.self, from: older)
        #expect(decoded.skinSmoothing == 0)
        // Nothing else of it moved.
        #expect(decoded.exposure == 20 && decoded.filter == .studio)
        #expect(LookSettings(decoded).skinSmoothing == 0)
    }

    @Test func aDamagedValueCountsAsOffAndOneOutOfRangeIsKept() throws {
        let take = edit()
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(take)) as? [String: Any])
        object["skinSmoothing"] = "a lot"
        #expect(try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: object)).skinSmoothing == 0)
        object["skinSmoothing"] = 900
        #expect(try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: object)).skinSmoothing == 100)
        object["skinSmoothing"] = -40
        #expect(try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: object)).skinSmoothing == 0)
    }

    @Test func aClipsValueIsSavedAndOlderClipsHaveNone() throws {
        var look = ClipLook()
        look.skinSmoothing = 45
        let decoded = try JSONDecoder().decode(ClipLook.self, from: JSONEncoder().encode(look))
        #expect(decoded.skinSmoothing == 45)
        look.exposure = 5
        let older = try json(look, removing: ["skinSmoothing"])
        let reread = try JSONDecoder().decode(ClipLook.self, from: older)
        #expect(reread.skinSmoothing == nil && reread.exposure == 5)
    }

    // MARK: - Clips

    @Test func aClipWithNothingSetPlaysWithTheTakesValue() {
        var take = edit()
        take.skinSmoothing = 40
        #expect(take.lookSettings(for: take.timeline.segments[0]).skinSmoothing == 40)
    }

    @Test func aClipsOwnValueReplacesTheTakesForThatClipOnly() {
        var take = edit()
        take.skinSmoothing = 40
        var clip = take.timeline.segments[0]
        var override = ClipLook()
        override.skinSmoothing = 10
        clip.look = override
        let look = take.lookSettings(for: clip)
        #expect(look.skinSmoothing == 10)
        #expect(take.skinSmoothing == 40)
        // A clip can turn it off while the take has it on.
        override.skinSmoothing = 0
        clip.look = override
        #expect(take.lookSettings(for: clip).skinSmoothing == 0)
        #expect(override.overridesAdjustment, "a 0 on the clip is a choice, not 'nothing set'")
    }

    @Test func settingOnlySkinSmoothingOverridesTheAdjustmentAndRemovingItClearsIt() {
        var look = ClipLook()
        #expect(!look.overridesAdjustment)
        look.skinSmoothing = 30
        #expect(look.overridesAdjustment && !look.isEmpty && look.normalized != nil)
        look.removeAdjustment()
        #expect(look.skinSmoothing == nil && look.isEmpty && look.normalized == nil)
    }

    @Test func splittingAClipKeepsItsSmoothingOnBothPieces() throws {
        var take = edit()
        var clip = take.timeline.segments[0]
        var override = ClipLook()
        override.skinSmoothing = 55
        clip.look = override
        take.timeline.replaceSegment(clip)
        let pieces = take.timeline.split(atEdited: 8)
        #expect(pieces)
        #expect(take.timeline.segments.count == 2)
        #expect(take.timeline.segments.allSatisfy { $0.look?.skinSmoothing == 55 })
    }

    // MARK: - Compare, undo

    @Test func compareDrawsTheTakeWithoutSmoothingOnTheTakeOrOnAnyClip() {
        var take = edit()
        take.skinSmoothing = 50
        var clip = take.timeline.segments[0]
        var override = ClipLook()
        override.skinSmoothing = 70
        override.background = BackgroundEffect()
        clip.look = override
        take.timeline.replaceSegment(clip)
        let plain = take.withoutPictureLook()
        #expect(plain.skinSmoothing == 0)
        #expect(plain.timeline.segments[0].look?.skinSmoothing == nil)
        #expect(LookSettings(plain).isNeutral)
        #expect(take.skinSmoothing == 50, "Compare never changes what is saved")
    }

    @Test func undoTakesSkinSmoothingBackAndStepsFromBeforeLeaveItAlone() throws {
        var changed = edit()
        changed.skinSmoothing = 65
        let step = EditLook(changed)
        var current = edit()
        current.skinSmoothing = 20
        step.apply(to: &current)
        #expect(current.skinSmoothing == 65)
        // A step saved before Skin Smoothing existed has no value: what is there stays.
        let older = try json(EditLook(edit()), removing: ["skinSmoothing"])
        let before = try JSONDecoder().decode(EditLook.self, from: older)
        #expect(before.skinSmoothing == nil)
        var kept = edit()
        kept.skinSmoothing = 80
        before.apply(to: &kept)
        #expect(kept.skinSmoothing == 80)
    }
}
