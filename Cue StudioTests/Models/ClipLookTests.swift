//
//  ClipLookTests.swift
//  Cue StudioTests
//

import CoreImage
import CoreMedia
import Foundation
import Testing
@testable import Cue_Studio

/// A clip's look is overrides over the take's: nothing set plays with the take's, a value set
/// replaces it for that clip only, and cutting or duplicating a clip never changes how it looks.
@Suite("Clip look")
struct ClipLookTests {
    private func edit(duration: TimeInterval = 20) -> TakeEdit {
        TakeEdit(sourceDuration: duration, aspect: .portrait)
    }

    // MARK: - Base and overrides

    @Test func aClipWithNothingSetPlaysWithTheTakesLook() {
        var take = edit()
        take.exposure = 20
        take.filter = .warm
        take.filterAmount = 0.6
        let look = take.lookSettings(for: take.timeline.segments[0])
        #expect(look.exposure == 20 && look.filter == .warm && look.filterAmount == 0.6)
        #expect(look == LookSettings(take))
    }

    @Test func aValueSetOnTheClipReplacesTheTakesAndNothingElse() {
        var take = edit()
        take.exposure = 20
        take.contrast = 10
        take.filter = .warm
        var clip = take.timeline.segments[0]
        var override = ClipLook()
        override.exposure = -15
        override.filter = .mono
        clip.look = override
        let look = take.lookSettings(for: clip)
        #expect(look.exposure == -15)
        #expect(look.contrast == 10)
        #expect(look.filter == .mono)
        #expect(look.filterAmount == take.filterAmount)
    }

    @Test func theTakesChangesReachEveryValueAClipLeavesAlone() {
        var take = edit()
        var clip = take.timeline.segments[0]
        var override = ClipLook()
        override.warmth = 30
        clip.look = override
        take.warmth = 5
        take.saturation = 40
        let look = take.lookSettings(for: clip)
        #expect(look.warmth == 30)
        #expect(look.saturation == 40)
    }

    @Test func removingEveryOverrideLeavesNothing() {
        var look = ClipLook()
        look.exposure = 5
        look.filter = .vivid
        look.filterAmount = 0.5
        #expect(look.overridesAdjustment && look.overridesFilter && look.normalized != nil)
        look.removeAdjustment()
        look.removeFilter()
        #expect(look.isEmpty && look.normalized == nil)
    }

    @Test func theOriginalFilterIsAPickOfItsOwn() {
        var look = ClipLook()
        look.filter = VideoFilter.original
        #expect(look.overridesFilter && !look.isEmpty)
        var take = edit()
        take.filter = .warm
        #expect(LookSettings(take).overridden(by: look).filter == .original)
    }

    // MARK: - Background

    @Test func aClipsBackgroundIsItsOwnElseItsRecordings() {
        var take = edit()
        var blur = BackgroundEffect()
        blur.style = .blur
        take.setBackground(blur, for: nil)
        var clip = take.timeline.segments[0]
        #expect(take.background(for: clip)?.style == .blur)
        var color = BackgroundEffect()
        color.style = .color
        var look = ClipLook()
        look.background = color
        clip.look = look
        #expect(take.background(for: clip)?.style == .color)
        // An Original one of its own means no effect on the clip, whatever its recording has.
        look.background = BackgroundEffect()
        clip.look = look
        #expect(take.background(for: clip) == nil)
    }

    @Test func aClipsBackgroundPhotoIsKeptWithTheEditsFiles() {
        var take = edit()
        var photo = BackgroundEffect()
        photo.style = .image
        photo.imageFileName = "clip-background.jpg"
        var clip = take.timeline.segments[0]
        var look = ClipLook()
        look.background = photo
        clip.look = look
        take.timeline.replaceSegment(clip)
        #expect(take.mediaFileNames.contains("clip-background.jpg"))
    }

    // MARK: - Saving and opening

    @Test func clipsSavedBeforeLooksOpenWithoutOne() throws {
        let json = #"{"id":"8C2A1B54-3D5B-4C3C-9B3B-1E0E1F7C0A11","sourceStart":0,"sourceEnd":4}"#
        let clip = try JSONDecoder().decode(EditSegment.self, from: Data(json.utf8))
        #expect(clip.look == nil)
    }

    @Test func aLookSurvivesSavingAndAnEmptyOneIsNotSaved() throws {
        var clip = EditSegment(sourceStart: 0, sourceEnd: 4)
        var look = ClipLook()
        look.exposure = 12
        look.filter = .fade
        look.filterAmount = 0.4
        clip.look = look
        let reopened = try JSONDecoder().decode(EditSegment.self, from: JSONEncoder().encode(clip))
        #expect(reopened.look == look)
        clip.look = ClipLook()
        let emptied = try JSONDecoder().decode(EditSegment.self, from: JSONEncoder().encode(clip))
        #expect(emptied.look == nil)
    }

    @Test func anEditWithClipLooksSurvivesSaving() throws {
        var take = edit()
        var clip = take.timeline.segments[0]
        var look = ClipLook()
        look.shadows = 25
        clip.look = look
        take.timeline.replaceSegment(clip)
        let reopened = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(take))
        #expect(reopened.timeline.segments[0].look == look)
    }

    // MARK: - Cutting and duplicating

    @Test func splittingAClipKeepsItsLookOnBothPieces() throws {
        var take = edit()
        var clip = take.timeline.segments[0]
        var look = ClipLook()
        look.filter = .mono
        look.exposure = 10
        clip.look = look
        take.timeline.replaceSegment(clip)
        #expect(take.timeline.split(atEdited: 8))
        #expect(take.timeline.segments.count == 2)
        #expect(take.timeline.segments.allSatisfy { $0.look == look })
    }

    @Test func duplicatingAClipKeepsItsLook() throws {
        var take = edit()
        var clip = take.timeline.segments[0]
        var look = ClipLook()
        look.contrast = 30
        clip.look = look
        take.timeline.replaceSegment(clip)
        let copy = try #require(take.timeline.duplicateSegment(id: clip.id))
        #expect(take.timeline.segment(id: copy)?.look == look)
    }

    @Test func removingAPartKeepsTheLookOfTheClipsAroundIt() {
        var take = edit()
        var clip = take.timeline.segments[0]
        var look = ClipLook()
        look.saturation = -40
        clip.look = look
        take.timeline.replaceSegment(clip)
        #expect(take.timeline.remove([TimeSpan(start: 5, end: 8)]))
        #expect(take.timeline.segments.count == 2)
        #expect(take.timeline.segments.allSatisfy { $0.look == look })
    }

    // MARK: - Drawing

    @Test func stretchesCutWhereTheNextClipLooksDifferentAndOnlyThere() {
        var take = edit()
        #expect(take.timeline.split(atEdited: 5))
        #expect(take.timeline.split(atEdited: 12))
        let whole = [(range: CMTimeRange(start: .zero, end: CMTime(seconds: 20, preferredTimescale: 600)), dissolve: nil as TransitionWindow?, showsMedia: false)]
        #expect(EditedComposition.splitBySource(whole, in: take.timeline).count == 1)
        var middle = take.timeline.segments[1]
        var look = ClipLook()
        look.filter = .mono
        middle.look = look
        take.timeline.replaceSegment(middle)
        let stretches = EditedComposition.splitBySource(whole, in: take.timeline)
        #expect(stretches.map { $0.range.end.seconds } == [5, 12, 20])
    }

    /// One pixel of `image`, rendered.
    private func pixel(_ image: CIImage) -> (red: UInt8, green: UInt8, blue: UInt8) {
        var bytes = [UInt8](repeating: 0, count: 4)
        CIContext().render(
            image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (bytes[0], bytes[1], bytes[2])
    }

    @Test func theTakesLookDrawsTheSameThroughTheTakeOrTheSettings() {
        var take = edit()
        take.exposure = 30
        take.filter = .warm
        take.filterAmount = 0.7
        let source = CIImage(color: CIColor(red: 0.5, green: 0.3, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        let viaTake = pixel(FrameLook.apply(take, to: source))
        let viaSettings = pixel(FrameLook.apply(LookSettings(take), to: source))
        #expect(viaTake == viaSettings)
        #expect(viaTake != pixel(source))
    }

    @Test func aClipsOwnFilterDrawsDifferentlyFromTheTakes() {
        var take = edit()
        take.filter = .vivid
        var clip = take.timeline.segments[0]
        var look = ClipLook()
        look.filter = .mono
        clip.look = look
        let source = CIImage(color: CIColor(red: 0.8, green: 0.3, blue: 0.1)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        let own = pixel(FrameLook.apply(take.lookSettings(for: clip), to: source))
        let base = pixel(FrameLook.apply(LookSettings(take), to: source))
        #expect(own != base)
        // Mono has no color left.
        #expect(abs(Int(own.red) - Int(own.blue)) < 6 && abs(Int(own.red) - Int(own.green)) < 6)
        #expect(abs(Int(base.red) - Int(base.blue)) > 20)
    }
}
