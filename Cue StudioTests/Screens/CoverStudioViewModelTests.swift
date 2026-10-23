//
//  CoverStudioViewModelTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Cover Studio's own logic: a new cover from the playhead with a suggested title and its key word, templates that keep the
/// creator's work, gestures that are one undo step, graphics as things of their own, a before/after with its own picture and
/// divider, the effect that needs a person saying when there is none, and the saved style without another cover's words.
@MainActor
@Suite("Cover Studio")
struct CoverStudioViewModelTests {
    private let canvas = CGSize(width: 270, height: 480)

    private func makeStudio(
        cover: VideoCover? = nil, suggestions: [String] = ["Three morning habits"], pictures: FakeCoverPictures = FakeCoverPictures(),
        styles: FakeTextStyleStore = FakeTextStyleStore()
    ) -> CoverStudioViewModel {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.voiceEnhancement = .off
        return CoverStudioViewModel(
            cover: cover, frame: CoverFrame(sourceID: nil, segmentID: edit.timeline.segments[0].id, time: 4), edit: edit,
            videoURL: URL(fileURLWithPath: "/tmp/take.mov"), handle: "maya", suggestions: suggestions,
            pictures: pictures, importer: FakeMediaImporter(), styles: styles
        )
    }

    @Test func aNewCoverStartsFromTheFrameWithASuggestedTitle() async {
        let studio = makeStudio()
        await studio.start()
        #expect(studio.step == .image)
        #expect(studio.cover.title == "Three morning habits")
        #expect(studio.composition.title.highlights == [1])
        await Wait.until { studio.rendered != nil }
        await Wait.until { studio.thumbnails.count == CoverTemplate.allCases.count }
    }

    @Test func aGestureIsOneUndoStepAndRedoBringsItBack() async {
        let studio = makeStudio()
        await studio.start()
        let start = studio.composition.title.center
        studio.beginGesture()
        for step in 1...10 { studio.moveTitle(from: start, by: CGSize(width: 0, height: CGFloat(step * 8)), in: canvas) }
        studio.endGesture()
        #expect(studio.composition.title.center.y > start.y)
        studio.undo()
        #expect(studio.composition.title.center == start)
        #expect(!studio.canUndo)
        studio.redo()
        #expect(studio.composition.title.center.y > start.y)
    }

    @Test func typingIsOneUndoStepAndTheHistoryKeepsSixty() async {
        let studio = makeStudio()
        await studio.start()
        let before = studio.cover.title
        for count in 1..."Morning".count { studio.setTitle(String("Morning".prefix(count))) }
        #expect(studio.cover.title == "Morning")
        studio.undo()
        #expect(studio.cover.title == before)
        #expect(!studio.canUndo)
        // Like the editor's: the oldest steps go past 60.
        for step in 0..<70 { studio.setZoom(1 + Double(step % 2) * 0.2) }
        #expect(studio.history.past.count == EditHistory<VideoCover>.limit)
    }

    @Test func aDraggedTitleSticksToTheMiddleAndTheThirds() async {
        let studio = makeStudio()
        await studio.start()
        studio.updateTitle { $0.center = OverlayPoint(x: 0.3, y: 0.3) }
        studio.beginGesture()
        // To x 0.495, y 0.335: the middle across and a third down.
        studio.moveTitle(from: OverlayPoint(x: 0.3, y: 0.3), by: CGSize(width: 0.195 * canvas.width, height: 0.035 * canvas.height), in: canvas)
        #expect(studio.composition.title.center.x == 0.5)
        #expect(abs(studio.composition.title.center.y - 1.0 / 3) < 0.000_1)
        #expect(studio.guides.vertical)
        studio.endGesture()
        #expect(!studio.guides.vertical)
    }

    @Test func graphicsArePickedMovedTurnedCopiedAndStacked() async throws {
        let studio = makeStudio()
        await studio.start()
        studio.addItem(.circle)
        studio.addItem(.tag)
        let tag = try #require(studio.selectedItem)
        #expect(tag.kind == .tag && tag.text == "NEW")
        #expect(studio.step == .elements)
        // Turned close to upright: it sticks to it.
        studio.transformItem(tag.id, from: (1, 0), scale: 1.5, rotation: 0.05)
        #expect(studio.composition.item(tag.id)?.rotation == 0)
        #expect(studio.composition.item(tag.id)?.scale == 1.5)
        studio.duplicateItem(tag.id)
        #expect(studio.composition.items.count == 3)
        let copy = try #require(studio.selectedItem)
        #expect(copy.id != tag.id)
        #expect(!studio.canRestack(copy.id, forward: true))
        studio.restackItem(copy.id, forward: false)
        #expect(studio.composition.items.last?.id == tag.id)
        // A tap lands on the one drawn on top.
        let frame = studio.itemFrame(try #require(studio.composition.items.last), in: canvas)
        studio.tap(at: frame.center, in: canvas)
        #expect(studio.selection == .item(tag.id))
        studio.deleteItem(tag.id)
        #expect(studio.selection == nil)
        #expect(studio.composition.items.count == 2)
    }

    @Test func aTapOnTheTitleOpensTitleAndOnNothingLetsGo() async throws {
        let studio = makeStudio()
        await studio.start()
        let frame = try #require(studio.titleFrame(in: canvas))
        studio.tap(at: CGPoint(x: frame.midX, y: frame.midY), in: canvas)
        #expect(studio.selection == .title)
        #expect(studio.step == .text)
        studio.tap(at: CGPoint(x: 3, y: 3), in: canvas)
        #expect(studio.selection == nil)
    }

    /// A tap finds a thing exactly where its handle takes a finger: just inside the title's touch frame picks it, just outside
    /// lets go; a before/after's line picks the divider only at its knob.
    @Test func aTapFindsWhatTheHandlesTake() async throws {
        let studio = makeStudio()
        await studio.start()
        let touch = CoverStudioViewModel.titleTouchFrame(try #require(studio.titleFrame(in: canvas)))
        studio.tap(at: CGPoint(x: touch.midX, y: touch.minY + 1), in: canvas)
        #expect(studio.selection == .title)
        studio.tap(at: CGPoint(x: touch.midX, y: touch.minY - 1), in: canvas)
        #expect(studio.selection != .title)

        studio.applyTemplate(.beforeAfter)
        let split = try #require(studio.composition.activeSplit)
        let knob = CoverStudioViewModel.dividerTouchFrame(position: split.position, in: canvas)
        #expect(studio.hit(at: CGPoint(x: knob.midX, y: knob.midY), in: canvas) == .divider)
        #expect(studio.hit(at: CGPoint(x: knob.midX, y: knob.minY - 4), in: canvas) != .divider)
    }

    @Test func aBeforeAfterHasItsOwnPictureFramingAndDivider() async throws {
        let studio = makeStudio()
        await studio.start()
        studio.applyTemplate(.beforeAfter)
        #expect(studio.composition.split != nil)
        studio.editsSecondPicture = true
        studio.useFrame(atEdited: 15)
        #expect(studio.composition.split?.source?.frame?.time == 15)
        #expect(studio.cover.source.frame?.time == 4)
        studio.setZoom(2)
        #expect(studio.composition.split?.framing.zoom == 2)
        #expect(studio.composition.framing.zoom == 1)
        studio.moveDivider(to: 0.95)
        #expect(studio.composition.split?.position == CoverSplit.positionRange.upperBound)
        studio.setSplitLabels(before: "ANTES")
        #expect(studio.composition.split?.beforeLabel == "ANTES")
        // Another template and back: the second picture and labels stay.
        studio.applyTemplate(.opinion)
        studio.applyTemplate(.beforeAfter)
        #expect(studio.composition.split?.beforeLabel == "ANTES")
    }

    @Test func textBehindMeSaysWhenThereIsNoPerson() async {
        let pictures = FakeCoverPictures()
        pictures.findsPerson = false
        let studio = makeStudio(pictures: pictures)
        await studio.start()
        studio.setEffect(.lift)
        await Wait.until { studio.personFound != nil }
        #expect(studio.personFound == false)
    }

    @Test func aPictureThatCantBeReadSaysSo() async {
        let pictures = FakeCoverPictures()
        pictures.missing = [.clipFrame(CoverFrame(sourceID: nil, segmentID: nil, time: 4))]
        let studio = makeStudio(cover: VideoCover(source: .clipFrame(CoverFrame(sourceID: nil, segmentID: nil, time: 4))), pictures: pictures)
        await studio.start()
        #expect(studio.pictureFailed)
        #expect(studio.rendered == nil)
    }

    @Test func myStyleIsSavedWithoutTheWords() async {
        let styles = FakeTextStyleStore()
        let studio = makeStudio(styles: styles)
        await studio.start()
        studio.applyTemplate(.series)
        studio.updateTitle { $0.accent = .mint }
        studio.saveMyStyle()
        #expect(styles.myCoverStyle?.template == .series)
        #expect(styles.myCoverStyle?.title.accent == .mint)
        #expect(styles.myCoverStyle?.title.highlights.isEmpty == true)
        // Applied to another cover: its words stay.
        let other = makeStudio(cover: VideoCover(source: .frame(1)), styles: styles)
        other.setTitle("Tea time")
        other.applyMyStyle()
        #expect(other.cover.title == "Tea time")
        #expect(other.composition.title.accent == .mint)
    }
}
