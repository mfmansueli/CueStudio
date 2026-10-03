//
//  LookVersionTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// A project never changes how it looks because the app learned to do better: an edit saved with
/// the first reading of the dials keeps it, one that never used them starts on the calibrated one,
/// and the calibrated look draws with neutral at zero.
@Suite("Look versions")
struct LookVersionTests {
    private func edit() -> TakeEdit {
        TakeEdit(sourceDuration: 20, aspect: .portrait)
    }

    private func pixel(_ image: CIImage) -> (red: Int, green: Int, blue: Int) {
        var bytes = [UInt8](repeating: 0, count: 4)
        CIContext().render(
            image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
    }

    private func source(_ red: Double, _ green: Double, _ blue: Double) -> CIImage {
        CIImage(color: CIColor(red: red, green: green, blue: blue)).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
    }

    /// Saved by an edit from before the version existed: the key is gone.
    private func savedBeforeVersions(_ edit: TakeEdit) throws -> TakeEdit {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(edit)) as? [String: Any])
        for key in ["lookVersion", "vibrance", "tint", "autoAmount", "autoCorrection"] { object.removeValue(forKey: key) }
        return try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: object))
    }

    // MARK: - Compatibility

    @Test func anEditThatUsedTheDialsKeepsTheFirstReading() throws {
        var old = edit()
        old.exposure = 20
        let decoded = try savedBeforeVersions(old)
        #expect(decoded.lookVersion == 1)
        #expect(LookSettings(decoded).version == 1)
        #expect(decoded.exposure == 20 && decoded.vibrance == 0 && decoded.tint == 0 && decoded.autoCorrection == nil)
    }

    @Test func aClipsDialsCountAsUsedToo() throws {
        var old = edit()
        var clip = old.timeline.segments[0]
        var look = ClipLook()
        look.contrast = 15
        clip.look = look
        old.timeline.replaceSegment(clip)
        #expect(try savedBeforeVersions(old).lookVersion == 1)
    }

    @Test func anEditThatNeverUsedThemStartsOnTheCalibratedReading() throws {
        var old = edit()
        old.filter = .film
        #expect(try savedBeforeVersions(old).lookVersion == LookSettings.currentVersion)
        #expect(edit().lookVersion == LookSettings.currentVersion)
    }

    @Test func theVersionIsSavedAndReadBack() throws {
        var old = edit()
        old.exposure = 20
        let first = try savedBeforeVersions(old)
        let again = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(first))
        #expect(again.lookVersion == 1)
        var fresh = edit()
        fresh.vibrance = 30
        fresh.autoCorrection = FakeTakeEditor.measuredCorrection
        fresh.autoAmount = 0.6
        let saved = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(fresh))
        #expect(saved.lookVersion == LookSettings.currentVersion && saved.vibrance == 30)
        #expect(saved.autoCorrection == FakeTakeEditor.measuredCorrection && saved.autoAmount == 0.6)
    }

    @Test func theFirstReadingStillDrawsWithTheFirstNumbers() {
        // +20 exposure was 0.24 stops; the calibrated reading is gentler there.
        var first = LookSettings()
        first.exposure = 20
        first.version = 1
        var calibrated = first
        calibrated.version = 2
        let image = source(0.3, 0.3, 0.3)
        let before = pixel(image)
        let old = pixel(FrameLook.apply(first, to: image))
        let new = pixel(FrameLook.apply(calibrated, to: image))
        #expect(old.green > new.green && new.green > before.green)
        // The same numbers as always: 2^0.24 in linear light.
        let linear = pow(0.3, 2.2) * pow(2, 0.24)
        let expected = Int((pow(linear, 1 / 2.2) * 255).rounded())
        #expect(abs(old.green - expected) <= 3)
    }

    @Test func theFirstFiltersDrawTheSameInEveryVersion() {
        for filter in VideoFilter.allCases where filter != .original {
            var first = LookSettings()
            first.filter = filter
            first.version = 1
            var calibrated = first
            calibrated.version = 2
            let image = source(0.7, 0.4, 0.3)
            #expect(pixel(FrameLook.apply(first, to: image)) == pixel(FrameLook.apply(calibrated, to: image)))
        }
    }

    // MARK: - Neutral and independent

    @Test func zeroIsNeutralInBothReadings() {
        let image = source(0.62, 0.41, 0.27)
        for version in [1, 2] {
            var look = LookSettings()
            look.version = version
            #expect(pixel(FrameLook.apply(look, to: image)) == pixel(image))
        }
        #expect(LookSettings().isNeutral)
    }

    @Test func eachDialDoesItsJobAndOnlyIt() {
        let image = source(0.5, 0.35, 0.3)
        let before = pixel(image)
        var warm = LookSettings()
        warm.warmth = 60
        let warmer = pixel(FrameLook.apply(warm, to: image))
        #expect(warmer.red > before.red && warmer.blue < before.blue)
        var cool = LookSettings()
        cool.warmth = -60
        let cooler = pixel(FrameLook.apply(cool, to: image))
        #expect(cooler.red < before.red && cooler.blue > before.blue)
        var magenta = LookSettings()
        magenta.tint = 100
        let tinted = pixel(FrameLook.apply(magenta, to: image))
        #expect(tinted.green < before.green)
        var vivid = LookSettings()
        vivid.vibrance = 80
        let lifted = pixel(FrameLook.apply(vivid, to: image))
        #expect(max(lifted.red, lifted.green, lifted.blue) - min(lifted.red, lifted.green, lifted.blue)
                > max(before.red, before.green, before.blue) - min(before.red, before.green, before.blue))
        var flat = LookSettings()
        flat.saturation = -100
        let gray = pixel(FrameLook.apply(flat, to: image))
        #expect(abs(gray.red - gray.green) <= 2 && abs(gray.green - gray.blue) <= 2)
    }

    @Test func contrastDarkensTheShadowsAndBrightensTheHighlightsAroundTheMiddle() {
        var look = LookSettings()
        look.contrast = 80
        let shadow = source(0.2, 0.2, 0.2)
        let light = source(0.8, 0.8, 0.8)
        let middle = source(0.5, 0.5, 0.5)
        #expect(pixel(FrameLook.apply(look, to: shadow)).green < pixel(shadow).green)
        #expect(pixel(FrameLook.apply(look, to: light)).green > pixel(light).green)
        #expect(abs(pixel(FrameLook.apply(look, to: middle)).green - pixel(middle).green) <= 2)
        // Less contrast: the other way round, the middle still where it was.
        look.contrast = -80
        #expect(pixel(FrameLook.apply(look, to: shadow)).green > pixel(shadow).green)
        #expect(pixel(FrameLook.apply(look, to: light)).green < pixel(light).green)
        #expect(abs(pixel(FrameLook.apply(look, to: middle)).green - pixel(middle).green) <= 2)
    }

    @Test func positiveHighlightsLiftTheBrightPartsAndLeaveTheShadows() {
        var look = LookSettings()
        look.highlights = 80
        let shadow = source(0.2, 0.2, 0.2)
        let light = source(0.8, 0.8, 0.8)
        #expect(abs(pixel(FrameLook.apply(look, to: shadow)).green - pixel(shadow).green) <= 2)
        #expect(pixel(FrameLook.apply(look, to: light)).green > pixel(light).green + 3)
    }

    // MARK: - Auto

    @Test func autoIsAStepOfItsOwnBeforeTheDials() {
        let image = source(0.3, 0.3, 0.3)
        var withAuto = LookSettings()
        withAuto.auto = FakeTakeEditor.measuredCorrection
        let corrected = pixel(FrameLook.apply(withAuto, to: image))
        #expect(corrected != pixel(image))
        // At no intensity it isn't there, and halfway it is halfway.
        withAuto.autoAmount = 0
        #expect(pixel(FrameLook.apply(withAuto, to: image)) == pixel(image))
        withAuto.autoAmount = 0.5
        let half = pixel(FrameLook.apply(withAuto, to: image)).green
        #expect(half != pixel(image).green)
        // The creator's dials stay on top, whatever Auto did.
        var both = withAuto
        both.autoAmount = 1
        both.exposure = 30
        #expect(pixel(FrameLook.apply(both, to: image)).green > corrected.green)
    }

    @Test func aClipsOverridesCoverAutoAndTheNewDials() {
        var take = edit()
        take.vibrance = 10
        take.autoCorrection = FakeTakeEditor.measuredCorrection
        var override = ClipLook()
        override.autoAmount = 0
        override.tint = -20
        #expect(override.overridesAdjustment && override.overridesAuto)
        let look = LookSettings(take).overridden(by: override)
        #expect(look.autoAmount == 0 && look.auto == FakeTakeEditor.measuredCorrection)
        #expect(look.tint == -20 && look.vibrance == 10)
        override.removeAuto()
        #expect(!override.overridesAuto)
        override.removeAdjustment()
        #expect(override.isEmpty)
    }

    @Test func comparingShowsThePictureAsRecordedAndKeepsTheBackground() {
        var take = edit()
        take.exposure = 10
        take.autoCorrection = FakeTakeEditor.measuredCorrection
        take.filter = .mono
        var clip = take.timeline.segments[0]
        var look = ClipLook()
        look.vibrance = 30
        look.filter = .vivid
        var blur = BackgroundEffect()
        blur.style = .blur
        look.background = blur
        clip.look = look
        take.timeline.replaceSegment(clip)
        #expect(take.hasPictureLook)
        let plain = take.withoutPictureLook()
        #expect(LookSettings(plain).isNeutral)
        #expect(plain.timeline.segments[0].look?.background?.style == .blur)
        #expect(plain.timeline.segments[0].look?.overridesAdjustment == false)
        #expect(!plain.hasPictureLook)
        #expect(!edit().hasPictureLook)
    }

    @Test func undoTakesBackAutoAndTheNewDials() {
        var changed = edit()
        changed.vibrance = 40
        changed.tint = -10
        changed.autoCorrection = FakeTakeEditor.measuredCorrection
        changed.autoAmount = 0.5
        let step = EditLook(changed)
        var restored = edit()
        step.apply(to: &restored)
        #expect(restored.vibrance == 40 && restored.tint == -10 && restored.autoAmount == 0.5)
        #expect(restored.autoCorrection == FakeTakeEditor.measuredCorrection)
        // A step saved before them leaves them as they are.
        var stale = step
        stale.autoAmount = nil
        var kept = changed
        stale.apply(to: &kept)
        #expect(kept.vibrance == 40 && kept.autoCorrection == FakeTakeEditor.measuredCorrection)
    }
}
