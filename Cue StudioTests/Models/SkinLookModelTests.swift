//
//  SkinLookModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Skin in the edit, apart from Adjust: off for a new edit, saved as one set (`skin`), an edit made with the first smoothing (Adjust's
/// `skinSmoothing` dial) opening on the engine it was made with, a clip setting any part of its own (0 included), and Compare, undo and
/// Reset keeping Skin and Adjust apart.
@Suite("Skin in the look")
struct SkinLookModelTests {
    private func edit(duration: TimeInterval = 20) -> TakeEdit {
        TakeEdit(sourceDuration: duration, aspect: .portrait)
    }

    private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }

    private func decode<T: Decodable>(_ type: T.Type, _ object: [String: Any]) throws -> T {
        try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: object))
    }

    /// `edit` as a build with Skin in Adjust saved it: the dial under `skinSmoothing`, no `skin`.
    private func savedByTheFirstSmoothing(_ take: TakeEdit, dial: Any) throws -> [String: Any] {
        var saved = try object(take)
        saved.removeValue(forKey: "skin")
        saved["skinSmoothing"] = dial
        return saved
    }

    private let studio = SkinLook(smoothing: SkinSmoothing(amount: 62, texture: 30), faceLight: 20, antiShine: 40)

    // MARK: - Off by default

    @Test func everythingStartsOffOnTodaysEngine() {
        #expect(edit().skin == SkinLook())
        #expect(!edit().skin.isOn && edit().skin.preset == nil)
        #expect(edit().skin.smoothing.engine == ReadingVersion.skin.current && ReadingVersion.skin.current == 2)
        #expect(edit().skin.smoothing.texture == SkinBeautyCalibration.defaultTexture)
        #expect(LookSettings().skin == SkinLook() && LookSettings(edit()).skin == SkinLook())
        #expect(ClipLook().skin == nil)
        #expect(!edit().hasPictureLook && !edit().hasSkin)
        #expect(LookSettings().isNeutral)
    }

    @Test func anyPartOfSkinIsAChange() {
        for skin in [SkinLook.smoothing(30), SkinLook(faceLight: 10), SkinLook(antiShine: 5)] {
            var take = edit()
            take.skin = skin
            #expect(skin.isOn && take.hasSkin && take.hasPictureLook)
            #expect(!LookSettings(take).isNeutral)
        }
    }

    @Test func valuesStayInRange() {
        let skin = SkinLook(smoothing: SkinSmoothing(amount: 250, texture: -10), faceLight: .nan, antiShine: 140)
        #expect(skin.smoothing.amount == 100 && skin.smoothing.texture == 0)
        #expect(skin.faceLight == 0 && skin.antiShine == 100)
        #expect(ClipSkin(faceLight: -4, antiShine: .infinity).faceLight == 0)
        #expect(ClipSkin(antiShine: .infinity).antiShine == 0)
    }

    @Test func thePresetsAreExactValuesAndAnEditedOneIsCustom() {
        #expect(SkinPreset.natural.look.preset == .natural && SkinPreset.studio.look.preset == .studio)
        #expect(SkinPreset.studio.look.smoothing.amount > SkinPreset.natural.look.smoothing.amount)
        #expect(SkinPreset.studio.look.smoothing.texture < SkinPreset.natural.look.smoothing.texture)
        var edited = SkinPreset.natural.look
        edited.faceLight += 1
        #expect(edited.preset == nil)
        // A first-engine smoothing is never a preset, even with the same numbers.
        var older = SkinPreset.natural.look
        older.smoothing.engine = ReadingVersion.skin.first
        #expect(older.preset == nil)
    }

    // MARK: - Saved edits

    @Test func skinIsSavedAsOneSetAndNeverAsTheOldDial() throws {
        var take = edit()
        take.skin = studio
        let saved = try object(take)
        #expect(saved["skinSmoothing"] == nil)
        let skin = try #require(saved["skin"] as? [String: Any])
        let smoothing = try #require(skin["smoothing"] as? [String: Any])
        #expect(smoothing["engine"] as? Int == 2 && smoothing["texture"] as? Double == 30)
        let decoded = try decode(TakeEdit.self, saved)
        #expect(decoded.skin == studio && decoded == take)
    }

    @Test func anEditMadeWithTheFirstSmoothingOpensOnItsEngine() throws {
        var take = edit()
        take.exposure = 20
        take.filter = .studio
        let decoded = try decode(TakeEdit.self, savedByTheFirstSmoothing(take, dial: 60))
        #expect(decoded.skin.smoothing == SkinSmoothing(amount: 60, engine: 1))
        #expect(decoded.skin.smoothing.usesFirstEngine && decoded.skin.isOn)
        #expect(decoded.skin.faceLight == 0 && decoded.skin.antiShine == 0)
        // Nothing else of it moved.
        #expect(decoded.exposure == 20 && decoded.filter == .studio)
        #expect(LookSettings(decoded).skin.smoothing.engine == 1)
    }

    @Test func savingAndReopeningKeepsTheFirstEngineAndDropsTheOldKey() throws {
        let opened = try decode(TakeEdit.self, savedByTheFirstSmoothing(edit(), dial: 45))
        let saved = try object(opened)
        #expect(saved["skinSmoothing"] == nil, "the old dial is read, never written")
        let reopened = try decode(TakeEdit.self, saved)
        #expect(reopened.skin.smoothing == SkinSmoothing(amount: 45, engine: 1))
        #expect(reopened == opened)
    }

    @Test func anEditWhoseOldDialWasOffGetsTodaysEngine() throws {
        let decoded = try decode(TakeEdit.self, savedByTheFirstSmoothing(edit(), dial: 0))
        #expect(decoded.skin == SkinLook())
        #expect(!decoded.skin.smoothing.usesFirstEngine)
        let older = try object(edit()).filter { $0.key != "skin" }
        #expect(try decode(TakeEdit.self, older).skin == SkinLook(), "saved before Skin Smoothing existed")
    }

    @Test func aDamagedOldDialCountsAsOffAndOneOutOfRangeIsBroughtIn() throws {
        #expect(try decode(TakeEdit.self, savedByTheFirstSmoothing(edit(), dial: "a lot")).skin == SkinLook())
        #expect(try decode(TakeEdit.self, savedByTheFirstSmoothing(edit(), dial: 900)).skin.smoothing == SkinSmoothing(amount: 100, engine: 1))
        #expect(try decode(TakeEdit.self, savedByTheFirstSmoothing(edit(), dial: -40)).skin == SkinLook())
    }

    @Test func aDamagedPartOfSkinIsOffAndTheOthersStay() throws {
        var take = edit()
        take.skin = studio
        var saved = try object(take)
        var skin = try #require(saved["skin"] as? [String: Any])
        skin["faceLight"] = "bright"
        skin["antiShine"] = 400
        saved["skin"] = skin
        let decoded = try decode(TakeEdit.self, saved)
        #expect(decoded.skin.faceLight == 0 && decoded.skin.antiShine == 100)
        #expect(decoded.skin.smoothing == studio.smoothing)
    }

    @Test func whenBothAreThereSkinWins() throws {
        var take = edit()
        take.skin = studio
        var saved = try object(take)
        saved["skinSmoothing"] = 90
        #expect(try decode(TakeEdit.self, saved).skin == studio)
    }

    @Test func aSmoothingSavedWithoutItsEngineIsTheFirsts() throws {
        let smoothing = try decode(SkinSmoothing.self, ["amount": 30])
        #expect(smoothing.engine == 1 && smoothing.texture == SkinBeautyCalibration.defaultTexture)
    }

    @Test func aSmoothingFromANewerCueIsKeptButNotDrawn() throws {
        let smoothing = try decode(SkinSmoothing.self, ["amount": 30, "texture": 20, "engine": 9])
        #expect(smoothing.engine == 9 && !smoothing.isOn)
        #expect(!SkinLook(smoothing: smoothing).isOn)
        var take = edit()
        take.skin.smoothing = smoothing
        #expect(LookSettings(take).isNeutral)
        let reread = try decode(TakeEdit.self, try object(take))
        #expect(reread.skin.smoothing.engine == 9, "saved again as it came")
    }

    @Test func aClipsOldDialOpensOnTheFirstEngineAndAZeroStaysAChoice() throws {
        var look = ClipLook()
        look.exposure = 5
        var saved = try object(look)
        saved["skinSmoothing"] = 45
        let decoded = try decode(ClipLook.self, saved)
        #expect(decoded.skin == ClipSkin(smoothing: SkinSmoothing(amount: 45, engine: 1)))
        #expect(decoded.exposure == 5)
        #expect(try object(decoded)["skinSmoothing"] == nil)
        saved["skinSmoothing"] = 0
        let off = try decode(ClipLook.self, saved)
        #expect(off.skin?.smoothing?.amount == 0, "a clip that turned the old dial to 0 keeps it off")
        #expect(off.overridesSkin)
        saved.removeValue(forKey: "skinSmoothing")
        #expect(try decode(ClipLook.self, saved).skin == nil)
    }

    @Test func aClipsSkinIsSavedWithEachPartOrNone() throws {
        var look = ClipLook()
        look.skin = ClipSkin(faceLight: 0)
        let decoded = try JSONDecoder().decode(ClipLook.self, from: JSONEncoder().encode(look))
        #expect(decoded.skin == ClipSkin(faceLight: 0))
        look.skin = ClipSkin()
        #expect(try JSONDecoder().decode(ClipLook.self, from: JSONEncoder().encode(look)).skin == nil, "an empty set is nothing set")
    }

    // MARK: - Clips

    @Test func aClipWithNothingSetPlaysWithTheVideosSkin() {
        var take = edit()
        take.skin = studio
        #expect(take.lookSettings(for: take.timeline.segments[0]).skin == studio)
    }

    @Test func aClipsOwnPartsReplaceTheVideosForThatClipOnly() {
        var take = edit()
        take.skin = studio
        var clip = take.timeline.segments[0]
        var override = ClipLook()
        override.skin = ClipSkin(faceLight: 0)
        clip.look = override
        let look = take.lookSettings(for: clip).skin
        #expect(look.faceLight == 0, "a 0 on the clip is a choice, not 'nothing set'")
        #expect(look.smoothing == studio.smoothing && look.antiShine == studio.antiShine)
        #expect(take.skin == studio)
    }

    @Test func skinAndAdjustAreApartOnAClip() {
        var look = ClipLook()
        look.skin = ClipSkin(antiShine: 30)
        #expect(look.overridesSkin && !look.overridesAdjustment)
        look.removeAdjustment()
        #expect(look.skin == ClipSkin(antiShine: 30), "Adjust's Reset leaves Skin")
        look.exposure = 10
        look.removeSkin()
        #expect(look.skin == nil && look.exposure == 10, "Skin's Reset leaves Adjust")
        #expect(look.overridesAdjustment && !look.overridesSkin)
        look.removeAdjustment()
        #expect(look.isEmpty && look.normalized == nil)
    }

    @MainActor @Test func theLookToolsCountAndClearOnlyTheirOwn() {
        var look = ClipLook()
        look.skin = ClipSkin(smoothing: .off)
        look.contrast = 12
        #expect(EditorLookTool.skin.isOwn(in: look) && EditorLookTool.adjust.isOwn(in: look))
        var cleared = look
        EditorLookTool.skin.clear(&cleared)
        #expect(cleared.skin == nil && cleared.contrast == 12)
        cleared = look
        EditorLookTool.adjust.clear(&cleared)
        #expect(cleared.skin == look.skin && cleared.contrast == nil)
    }

    @Test func splittingAClipKeepsItsSkinOnBothPieces() throws {
        var take = edit()
        var clip = take.timeline.segments[0]
        var override = ClipLook()
        override.skin = ClipSkin(smoothing: SkinSmoothing(amount: 55, texture: 10), antiShine: 0)
        clip.look = override
        take.timeline.replaceSegment(clip)
        let didSplit = take.timeline.split(atEdited: 8)
        #expect(didSplit)
        #expect(take.timeline.segments.count == 2)
        #expect(take.timeline.segments.allSatisfy { $0.look?.skin == override.skin })
    }

    /// Duplicate, trim, speed, Replace clip and Reverse (the clip playing another recording) keep the clip's own Skin, and a clip added
    /// with the look of another (a frozen frame) has that clip's.
    @Test func aClipsSkinGoesWithItThroughEveryEdit() throws {
        var take = edit()
        var clip = take.timeline.segments[0]
        var override = ClipLook()
        override.skin = ClipSkin(smoothing: SkinSmoothing(amount: 70, texture: 20), faceLight: 0)
        clip.look = override
        take.timeline.replaceSegment(clip)
        let duplicated = take.timeline.duplicateSegment(id: clip.id)
        let copy = try #require(duplicated)
        let didTrim = take.timeline.trimSegment(id: copy, edge: .end, toSource: 12)
        let didSpeed = take.timeline.setSpeed(2, forSegmentAt: 1)
        #expect(didTrim && didSpeed)
        let replaced = take.timeline.replaceSource(ofSegment: clip.id, with: UUID(), duration: 15)
        let reversed = take.timeline.replaceSource(ofSegmentAt: 1, with: UUID(), duration: 12, span: TimeSpan(start: 0, end: 12))
        #expect(replaced != nil && reversed)
        let frozen = take.timeline.insertClip(source: UUID(), duration: 5, span: TimeSpan(start: 0, end: 2), at: 1, look: override)
        #expect(frozen != nil)
        #expect(take.timeline.segments.count == 3)
        #expect(take.timeline.segments.allSatisfy { $0.look?.skin == override.skin })
    }

    // MARK: - Compare, undo

    @Test func compareWithoutThePictureLookTakesSkinOffTooAndKeepsWhatIsSaved() {
        var take = edit()
        take.skin = studio
        var clip = take.timeline.segments[0]
        var override = ClipLook()
        override.skin = ClipSkin(faceLight: 70)
        override.background = BackgroundEffect()
        clip.look = override
        take.timeline.replaceSegment(clip)
        let plain = take.withoutPictureLook()
        #expect(plain.skin == SkinLook() && plain.timeline.segments[0].look?.skin == nil)
        #expect(LookSettings(plain).isNeutral)
        #expect(take.skin == studio, "Compare never changes what is saved")
    }

    @Test func compareWithoutSkinKeepsEverythingElse() {
        var take = edit()
        take.skin = studio
        take.exposure = 15
        take.filter = .studio
        var clip = take.timeline.segments[0]
        var override = ClipLook()
        override.skin = ClipSkin(faceLight: 70)
        override.contrast = 8
        override.background = BackgroundEffect(style: .blur)
        clip.look = override
        take.timeline.replaceSegment(clip)
        let plain = take.withoutSkin()
        #expect(plain.skin == SkinLook() && !plain.hasSkin)
        #expect(plain.exposure == 15 && plain.filter == .studio)
        let look = plain.timeline.segments[0].look
        #expect(look?.skin == nil && look?.contrast == 8 && look?.background == override.background)
    }

    @Test func undoStepsCarrySkinAndOlderStepsReadTheirDial() throws {
        var changed = edit()
        changed.skin = studio
        let step = EditLook(changed)
        var current = edit()
        current.skin = SkinLook(faceLight: 5)
        step.apply(to: &current)
        #expect(current.skin == studio)
        #expect(try object(step)["skinSmoothing"] == nil)
        // A step saved while the smoothing was in Adjust: its dial, on the first engine.
        var adjustStep = try object(EditLook(edit()))
        adjustStep.removeValue(forKey: "skin")
        adjustStep["skinSmoothing"] = 65
        var reopened = edit()
        try decode(EditLook.self, adjustStep).apply(to: &reopened)
        #expect(reopened.skin.smoothing == SkinSmoothing(amount: 65, engine: 1))
        // One saved before Skin Smoothing existed: what is there stays.
        adjustStep.removeValue(forKey: "skinSmoothing")
        var kept = edit()
        kept.skin = studio
        try decode(EditLook.self, adjustStep).apply(to: &kept)
        #expect(kept.skin == studio)
    }

    // MARK: - Update

    @Test func updatingMovesOnlyTheFirstEngineAndKeepsItAboutAsStrong() {
        let older = SkinSmoothing.firstEngine(80)
        let updated = older.updated
        #expect(updated.engine == ReadingVersion.skin.current && !updated.usesFirstEngine)
        #expect(updated.amount == SkinBeautyCalibration.updatedAmount(fromFirstEngine: 80))
        #expect(updated.amount > 0 && updated.amount < 80)
        let today = SkinSmoothing(amount: 40, texture: 20)
        #expect(today.updated == today)
    }
}
