//
//  QuickEditBlurTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Blur area in the editor: the faces of the frame offered, a tap hiding and following one in one undo step, a drawn area
/// staying put until followed, what wasn't followed marked and handled (Go there, a spot set by hand, It's right, End here),
/// Cancel keeping what was followed, a bar per showing on the timeline trimming the same area, Done asking first when
/// something is left unchecked, ◐, and deleting an area alone.
@MainActor
@Suite("Blur area in the editor", .serialized)
struct QuickEditBlurTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
        let tracker: FakeObjectTracker
    }

    /// A face walking right a tenth of the frame a second, from x 0.3 at 0 s.
    private static let walk: @Sendable (TimeInterval) -> NormalizedBox = { time in
        NormalizedBox(center: CGPoint(x: 0.3 + time * 0.1, y: 0.4), width: 0.1, height: 0.1)
    }

    /// A 10 s take, a face in every frame where `walk` has it.
    private func makeScenario(lostAfter: TimeInterval? = nil, delay: Duration = .zero, faces: [CGRect]? = nil) async -> Scenario {
        var take = TestData.take(scriptID: nil)
        take.duration = 10
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let editor = FakeTakeEditor()
        editor.duration = 10
        let tracker = FakeObjectTracker(path: Self.walk)
        tracker.lostAfter = lostAfter
        tracker.delay = delay
        let start = Self.walk(2)
        let finder = FakeFaceFinder(boxes: faces ?? [CGRect(x: start.x, y: start.y, width: start.width, height: start.height)])
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: toast,
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(),
            tracker: tracker, faceFinder: finder
        )
        await viewModel.prepare()
        player.seek(to: 2)
        return Scenario(viewModel: viewModel, player: player, toast: toast, tracker: tracker)
    }

    private func pickTheFace(_ viewModel: QuickEditViewModel) async {
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.pickFace(0)
        await Wait.until(timeout: .seconds(60)) { !viewModel.blur.isFollowing }
    }

    @Test func aTappedFaceIsHiddenAndFollowedAtOnce() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let steps = viewModel.document.history.past.count
        viewModel.perform(.addBlurArea)
        #expect(viewModel.panel == .blur)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        #expect(viewModel.blur.picking?.faces.count == 1)
        viewModel.blur.pickFace(0)
        await Wait.until(timeout: .seconds(60)) { !viewModel.blur.isFollowing }
        let region = try #require(viewModel.edit.blurRegions.first)
        #expect(viewModel.selection == .blur(region.id))
        #expect(region.subject == .face && region.shape == .oval)
        // The whole clip, tracked both ways from the playhead: on the face at 6 s and at 0.5 s.
        #expect(region.span == TimeSpan(start: 0, end: 10))
        #expect(abs(region.box(at: 6).midX - Self.walk(6).midX) < 0.01)
        #expect(abs(region.box(at: 0.5).midX - Self.walk(0.5).midX) < 0.01)
        #expect(region.isCovered)
        // Its card, in view, says it (tracking, then tracked: its sign jumps); no toast covers the top of the preview.
        #expect(scenario.toast.message == nil)
        #expect(viewModel.blur.followingEnded == 1)
        // Made and followed: two steps; one Undo takes the path, the next the area.
        #expect(viewModel.document.history.past.count == steps + 2)
        viewModel.undo()
        #expect(viewModel.edit.blurRegions.first?.moves == false)
        viewModel.undo()
        #expect(viewModel.edit.blurRegions.isEmpty)
    }

    @Test func whereTheFaceIsLostItIsMarkedAndCanBeFixedOrAccepted() async throws {
        let scenario = await makeScenario(lostAfter: 6)
        let viewModel = scenario.viewModel, player = scenario.player
        await pickTheFace(viewModel)
        var region = try #require(viewModel.edit.blurRegions.first)
        #expect(!region.isCovered)
        #expect(region.openUnchecked.count == 1)
        #expect(abs((region.openUnchecked.first?.start ?? 0) - 6) < 0.05)
        #expect(scenario.toast.message?.hasPrefix("Not tracked for") != true, "the card in view says it")
        #expect(viewModel.blur.followingEnded == 1)
        // Done stops to ask first.
        viewModel.askIfReadyToPost()
        #expect(viewModel.showsBlurCheck)
        #expect(viewModel.sheet == nil)
        viewModel.reviewUncheckedBlur()
        #expect(viewModel.panel == .blur)
        #expect(abs(player.currentTime - 6.05) < 0.05)
        #expect(viewModel.blur.playheadIsUnchecked)
        // Put back on the face by hand at 7 s: a spot of the creator's.
        player.seek(to: 7)
        viewModel.blur.place(BlurRegion.area(aroundFace: Self.walk(7)))
        region = try #require(viewModel.edit.blurRegions.first)
        #expect(region.keyframes.contains { abs($0.time - 7) < 0.02 && $0.isSet == true })
        // Looked at, it's right.
        viewModel.blur.markChecked()
        region = try #require(viewModel.edit.blurRegions.first)
        #expect(region.isCovered)
        #expect(scenario.toast.message == "Checked · Covered the whole time")
        // Nothing left: Done goes on.
        viewModel.askIfReadyToPost()
        #expect(viewModel.sheet == .done)
    }

    @Test func endHereAndTrackFromHere() async throws {
        let scenario = await makeScenario(lostAfter: 6)
        let viewModel = scenario.viewModel, player = scenario.player
        await pickTheFace(viewModel)
        // Track from here, in the lost stretch: the stretch only, from the playhead (the tracker loses it again past 6 s, so
        // the part after 7 s stays marked).
        player.seek(to: 7)
        viewModel.blur.followFromHere()
        await Wait.until(timeout: .seconds(60)) { !viewModel.blur.isFollowing }
        #expect(scenario.tracker.calls.last.map { abs($0.until - 6) < 0.1 } == true, "backwards to where the stretch starts")
        // End here: it stops at the playhead, and its marked tail goes with it.
        player.seek(to: 6.2)
        viewModel.blur.endHere()
        let region = try #require(viewModel.edit.blurRegions.first)
        #expect(abs(region.span.end - 6.2) < 0.01)
        #expect(region.uncheckedDuration < 0.25)
    }

    @Test func cancelKeepsWhatWasFollowed() async throws {
        let scenario = await makeScenario(delay: .milliseconds(15))
        let viewModel = scenario.viewModel
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.pickFace(0)
        await Wait.until { (viewModel.blur.following?.progress ?? 0) > 0.1 }
        viewModel.blur.cancelFollowing()
        await Wait.until(timeout: .seconds(60)) { !viewModel.blur.isFollowing }
        let region = try #require(viewModel.edit.blurRegions.first)
        #expect(region.moves, "what was tracked stays")
        #expect(region.uncheckedDuration > 1, "the rest is marked")
    }

    @Test func anAreaDrawnOverAFaceFollowsTheFaceAndOnePartOfItTheTracker() async throws {
        let scenario = await makeScenario(faces: [])
        let viewModel = scenario.viewModel
        // The recording's analysis: a face walking right, ten times a second.
        let url = try #require(viewModel.blur.url(of: .recording(nil)))
        var analysis = MotionAnalysis(duration: 10, width: 1080, height: 1920)
        analysis.analyzedUntil = 10
        analysis.subjects = stride(from: 0.0, through: 10, by: 0.1).map { SubjectSample(time: $0, faces: [Self.walk($0)], bodies: []) }
        // The analysis is kept only next to a recording that exists: a stand-in file where the take has none.
        let madeFile = !FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
        if madeFile { FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: Data()) }
        MotionAnalysisStore.save(analysis, forRecording: url)
        defer {
            try? FileManager.default.removeItem(at: MotionAnalysisStore.url(forRecording: url))
            if madeFile { try? FileManager.default.removeItem(at: url) }
        }
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.drawArea()
        // Dragged over the whole face at 2 s, and followed: the face's path, no tracker.
        let face = Self.walk(2)
        viewModel.blur.place(NormalizedBox(center: face.center, width: face.width * 1.3, height: face.height * 1.3))
        viewModel.perform(.followBlur)
        await Wait.until(timeout: .seconds(30)) { !viewModel.blur.isFollowing }
        let region = try #require(viewModel.edit.blurRegions.first)
        #expect(scenario.tracker.calls.isEmpty)
        #expect(abs(region.box(at: 7).midX - Self.walk(7).midX) < 0.02)
        #expect(abs(region.box(at: 7).width - face.width * 1.3) < 0.02, "the size it was drawn")
        // A small area over part of the face (its mouth): the tracker.
        viewModel.blur.place(NormalizedBox(center: CGPoint(x: face.midX, y: face.y + face.height - 0.02), width: 0.03, height: 0.02))
        viewModel.perform(.followBlur)
        await Wait.until(timeout: .seconds(30)) { !viewModel.blur.isFollowing }
        #expect(!scenario.tracker.calls.isEmpty)
        #expect(viewModel.edit.blurRegions.first?.isFollowed == true)
    }

    @Test func aNewAreaTakesTheLookTheCreatorLastGaveOne() async throws {
        let scenario = await makeScenario(faces: [])
        let viewModel = scenario.viewModel
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.drawArea()
        viewModel.blur.setStyle(.solid)
        viewModel.blur.setShape(.rectangle)
        viewModel.blur.setFeather(0)
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.drawArea()
        let second = try #require(viewModel.edit.blurRegions.last)
        #expect(viewModel.edit.blurRegions.count == 2)
        #expect(BlurLook(second) == BlurLook(style: .solid, shape: .rectangle, strength: 0.6, feather: 0))
    }

    @Test func trackedFromItsBarWithThePanelClosedItSaysSoInAToast() async throws {
        let scenario = await makeScenario(faces: [])
        let viewModel = scenario.viewModel
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.drawArea()
        viewModel.closePanel()
        #expect(viewModel.selectedBlur != nil)
        viewModel.perform(.followBlur)
        await Wait.until(timeout: .seconds(60)) { !viewModel.blur.isFollowing }
        #expect(scenario.toast.message == "Tracked the whole time")
        #expect(viewModel.blur.followingEnded == 0)
    }

    @Test func theLastLookIsKeptWithTheVideosEdit() async throws {
        let scenario = await makeScenario(faces: [])
        let viewModel = scenario.viewModel
        #expect(viewModel.edit.blurLook == nil)
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.drawArea()
        viewModel.blur.setStyle(.pixelate)
        let look = BlurLook(style: .pixelate, shape: .oval, strength: 0.6, feather: 0.5)
        #expect(viewModel.edit.blurLook == look)
        // Saved with the edit: the editor opened again on this video starts the next area with it.
        let reopened = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(viewModel.edit))
        #expect(reopened.blurLook == look)
        // Undo takes the look back with the change.
        viewModel.undo()
        #expect(viewModel.edit.blurLook == nil)
    }

    @Test func aDrawnAreaStaysPutUntilTrackedAndStartsWithTheFirstLook() async throws {
        let scenario = await makeScenario(faces: [])
        let viewModel = scenario.viewModel
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        #expect(viewModel.blur.picking?.faces.isEmpty == true)
        viewModel.blur.drawArea()
        let region = try #require(viewModel.edit.blurRegions.first)
        #expect(region.subject == .area && !region.moves && !region.isFollowed)
        // The first area of an edit: an oval, Blur at 60%, a 50% soft edge.
        #expect(BlurLook(region) == .initial)
        #expect(!viewModel.blur.isFollowing)
        #expect(scenario.tracker.calls.isEmpty)
        // Its toolbar: Edit, Track, Review, Add area, the editor's other tools after them, and Delete pinned.
        #expect(Array(viewModel.toolbarItems.map(\.id).prefix(4)) == ["editBlur", "followBlur", "reviewBlur", "addBlur"])
        #expect(viewModel.toolbarItems[4].startsGroup)
        #expect(!viewModel.toolbarItems.contains { $0.id == "blurArea" }, "Add area already adds one")
        #expect(viewModel.toolbarItems.last?.id == "delete")
        viewModel.perform(.deleteBlur)
        #expect(viewModel.edit.blurRegions.isEmpty)
        #expect(viewModel.selection == nil)
        viewModel.undo()
        #expect(viewModel.edit.blurRegions.count == 1)
    }

    @Test func everyFaceButTheLargestIsHiddenEachOnItsOwn() async throws {
        let big = CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.2)
        let small = [CGRect(x: 0.1, y: 0.2, width: 0.06, height: 0.06), CGRect(x: 0.8, y: 0.2, width: 0.05, height: 0.05)]
        let scenario = await makeScenario(faces: [big] + small)
        let viewModel = scenario.viewModel
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.pickAllButLargest()
        await Wait.until(timeout: .seconds(60)) { !viewModel.blur.isFollowing && viewModel.blur.followQueue.isEmpty }
        #expect(viewModel.edit.blurRegions.count == 2)
        #expect(viewModel.edit.blurRegions.allSatisfy { $0.box.width < 0.15 }, "not the creator's")
        #expect(viewModel.edit.blurRegions.allSatisfy { $0.isFollowed })
    }

    @Test func aCopyOfTheClipShowsTheAreaAgainAndEitherBarTrimsIt() async throws {
        let scenario = await makeScenario(faces: [])
        let viewModel = scenario.viewModel, player = scenario.player
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.drawArea()
        var region = try #require(viewModel.edit.blurRegions.first)
        // A shorter area, then the clip copied.
        viewModel.blur.resizeBar(region.id, instance: TimeSpan(start: 0, end: 10), edge: .end, to: 4)
        region = try #require(viewModel.edit.blurRegions.first)
        #expect(abs(region.span.end - 4) < 0.01)
        let clip = try #require(viewModel.edit.timeline.segments.first)
        viewModel.selection = .clip(clip.id)
        viewModel.perform(.duplicateClip)
        let instances = viewModel.blurInstances
        #expect(instances.count == 2)
        #expect(Set(instances.map(\.regionID)) == [region.id])
        #expect(instances[0].id != instances[1].id)
        // A tap on the copy's bar picks the area.
        viewModel.tapTimeline(.item(.blur, region.id))
        #expect(viewModel.selection == .blur(region.id))
        // The copy's start handle trims the area's start.
        viewModel.blur.resizeBar(region.id, instance: instances[1].span, edge: .start, to: instances[1].span.start + 1)
        region = try #require(viewModel.edit.blurRegions.first)
        #expect(abs(region.span.start - 1) < 0.01)
        _ = player
    }

    @Test func anAreaGrowsWithTheClipItCovers() async throws {
        let scenario = await makeScenario(lostAfter: nil)
        let viewModel = scenario.viewModel, player = scenario.player
        // A clip of 2–8 s, its face tracked.
        let clip = try #require(viewModel.edit.timeline.segments.first)
        var timeline = viewModel.edit.timeline
        timeline.trimSegment(id: clip.id, edge: .start, toSource: 2)
        timeline.trimSegment(id: clip.id, edge: .end, toSource: 8)
        viewModel.clips.commit(timeline)
        player.seek(to: 1)
        await pickTheFace(viewModel)
        var region = try #require(viewModel.edit.blurRegions.first)
        #expect(region.span == TimeSpan(start: 2, end: 8))
        #expect(region.isCovered)
        // Its start handle dragged out to 1 s: the area covers the new second, marked to check; one undo step with the drag.
        let steps = viewModel.document.history.past.count
        viewModel.beginChange()
        timeline = viewModel.edit.timeline
        timeline.trimSegment(id: clip.id, edge: .start, toSource: 1)
        viewModel.clips.commit(timeline)
        viewModel.endChange()
        region = try #require(viewModel.edit.blurRegions.first)
        #expect(abs(region.span.start - 1) < 0.01)
        #expect(region.openUnchecked == [TimeSpan(start: 1, end: 2)])
        #expect(viewModel.document.history.past.count == steps + 1)
    }

    @Test func anAreaCoversTheClipLengthenedAfterItWasShortened() async throws {
        let scenario = await makeScenario(faces: [])
        let viewModel = scenario.viewModel
        let clip = try #require(viewModel.edit.timeline.segments.first)
        var timeline = viewModel.edit.timeline
        timeline.trimSegment(id: clip.id, edge: .end, toSource: 8)
        viewModel.clips.commit(timeline)
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.drawArea()
        // Shortened to 6 s, then lengthened to 9 s: the area (0–8 s) reaches the new end.
        for end in [6.0, 9.0] {
            timeline = viewModel.edit.timeline
            timeline.trimSegment(id: clip.id, edge: .end, toSource: end)
            viewModel.beginChange()
            viewModel.clips.commit(timeline)
            viewModel.endChange()
        }
        let region = try #require(viewModel.edit.blurRegions.first)
        #expect(abs(region.span.end - 9) < 0.01)
        // An area the creator ended inside the clip keeps its end.
        viewModel.selection = .blur(region.id)
        scenario.player.seek(to: 5)
        viewModel.blur.endHere()
        timeline = viewModel.edit.timeline
        timeline.trimSegment(id: clip.id, edge: .end, toSource: 10)
        viewModel.clips.commit(timeline)
        #expect(abs((viewModel.edit.blurRegions.first?.span.end ?? 0) - 5) < 0.01)
    }

    @Test func onAReversedClipEndHereEndsWhatShowsAfterThePlayhead() async throws {
        let scenario = await makeScenario(faces: [])
        let viewModel = scenario.viewModel
        // The take's 0–10 s played backwards: edited 5 s shows its 5 s, edited 6 s its 4 s.
        var source = ClipSource(fileName: "reversed.mov", duration: 10, title: "Reversed")
        source.reversal = ClipReversal(sourceID: nil, span: TimeSpan(start: 0, end: 10))
        let clip = try #require(viewModel.edit.timeline.segments.first)
        viewModel.clips.changeEdit { edit in
            edit.sources = [source]
            _ = edit.timeline.replaceSource(ofSegment: clip.id, with: source.id, duration: 10, from: 0)
            let box = NormalizedBox(x: 0.3, y: 0.3, width: 0.3, height: 0.3)
            edit.blurRegions = [BlurRegion(target: .recording(nil), span: TimeSpan(start: 2, end: 8), box: box)]
        }
        let region = try #require(viewModel.edit.blurRegions.first)
        viewModel.selection = .blur(region.id)
        scenario.player.seek(to: 5)
        viewModel.blur.endHere()
        let ended = try #require(viewModel.edit.blurRegions.first)
        #expect(abs(ended.span.start - 5) < 0.01 && abs(ended.span.end - 8) < 0.01, "\(ended.span)")
    }

    @Test func aVideoSplitOrCopiedKeepsItsAreasAndAReplacedOneLosesThem() async throws {
        let scenario = await makeScenario(faces: [CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)])
        let viewModel = scenario.viewModel, player = scenario.player
        viewModel.overlays.addMedia(ImportedMedia(kind: .video, fileName: "v-\(UUID().uuidString).mov", aspect: 9.0 / 16, duration: 6))
        let media = try #require(viewModel.selectedMedia)
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.drawArea()
        #expect(viewModel.edit.blurRegions.count == 1)
        player.seek(to: 4)
        viewModel.overlays.splitMedia(media.id)
        let halves = viewModel.edit.media.map(\.id)
        #expect(halves.count == 2)
        #expect(Set(viewModel.edit.blurRegions.compactMap(\.target.mediaID)) == Set(halves))
        viewModel.overlays.duplicateMedia(halves[1])
        #expect(viewModel.edit.blurRegions.count == 3)
        let copy = try #require(viewModel.selectedMedia)
        viewModel.overlays.replaceMedia(copy.id, with: MediaPick(ImportedMedia(kind: .photo, fileName: "p-\(UUID().uuidString).jpg", aspect: 1, duration: nil)))
        #expect(!viewModel.edit.blurRegions.contains { $0.target.mediaID == copy.id })
        #expect(scenario.toast.message?.contains("Blur area was on the old one") == true)
    }

    @Test func aSecondTrackWaitsItsTurnAndAFailedOneIsMarked() async throws {
        let scenario = await makeScenario(delay: .milliseconds(5), faces: [])
        let viewModel = scenario.viewModel
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.drawArea()
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.drawArea()
        let ids = viewModel.edit.blurRegions.map { $0.id }
        viewModel.blur.follow(ids[0])
        viewModel.blur.follow(ids[1])
        await Wait.until(timeout: .seconds(60)) { !viewModel.blur.isFollowing && viewModel.blur.followQueue.isEmpty }
        #expect(viewModel.edit.blurRegions.allSatisfy { $0.isFollowed && $0.moves }, "both tracked, one after the other")
        // Done waits while one is tracked.
        viewModel.blur.follow(ids[0])
        viewModel.askIfReadyToPost()
        #expect(viewModel.sheet == nil)
        #expect(scenario.toast.message?.contains("still being tracked") == true)
        await Wait.until(timeout: .seconds(60)) { !viewModel.blur.isFollowing }
    }

    @Test func compareShowsTheVideoWithoutItsAreas() async throws {
        let scenario = await makeScenario(faces: [])
        let viewModel = scenario.viewModel
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        viewModel.blur.drawArea()
        viewModel.blur.blurCompare.show(true)
        #expect(viewModel.playedEdit.blurRegions.isEmpty)
        #expect(scenario.player.shown.last?.blurRegions.isEmpty == true)
        viewModel.blur.blurCompare.show(false)
        #expect(viewModel.playedEdit.blurRegions.count == 1)
        // Leaving the panel ends the comparison.
        viewModel.blur.blurCompare.show(true)
        viewModel.panel = nil
        #expect(!viewModel.blur.comparesOriginal)
    }

    @Test func anAreaOnAPhotoOverTheTakeIsOnThatPhoto() async throws {
        let scenario = await makeScenario(faces: [CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)])
        let viewModel = scenario.viewModel
        viewModel.overlays.addMedia(ImportedMedia(kind: .photo, fileName: "p-\(UUID().uuidString).jpg", aspect: 1, duration: nil))
        let media = try #require(viewModel.selectedMedia)
        viewModel.perform(.addBlurArea)
        await Wait.until { viewModel.blur.picking?.isSearching == false }
        #expect(viewModel.blur.picking?.footage.target == .media(media.id))
        viewModel.blur.pickFace(0)
        let region = try #require(viewModel.edit.blurRegions.first)
        #expect(region.target == .media(media.id))
        // A photo doesn't move: nothing tracked, nothing marked.
        #expect(scenario.tracker.calls.isEmpty)
        #expect(viewModel.edit.isOnPhoto(region))
    }
}
