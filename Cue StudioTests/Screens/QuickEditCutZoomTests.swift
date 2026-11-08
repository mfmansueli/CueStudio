//
//  QuickEditCutZoomTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Zoom › Punch in on cuts in one step (R1.3/R2.1: it took 9–10 taps), its lines, the kit's Zoom (Meu estilo), and Follow face's
/// warning over an imported recording (plan §19: a horizontal video with two people says so).
@MainActor
@Suite("Quick edit · Punch in on cuts")
struct QuickEditCutZoomTests {
    private static func kitsStore() -> BrandKitStore {
        let root = URL.temporaryDirectory.appending(path: "CutZoom-\(UUID().uuidString)", directoryHint: .isDirectory)
        return BrandKitStore(repository: LocalBrandKitRepository(directory: root.appending(path: "Kits")), directory: root.appending(path: "Kits"))
    }

    private func makeViewModel(edit: TakeEdit? = nil, kits: BrandKitStore = Self.kitsStore()) async -> (QuickEditViewModel, ToastService) {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        take.edit = edit
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let toast = ToastService()
        let root = URL.temporaryDirectory.appending(path: "CutZoomMedia-\(UUID().uuidString)", directoryHint: .isDirectory)
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: toast,
            player: FakeEditPlayback(), mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(),
            mediaLibrary: MediaLibraryStore(repository: LocalMediaLibraryRepository(directory: root), directory: root), brandKits: kits,
            editorPreferences: FakeEditorPreferencesStore()
        )
        await viewModel.prepare()
        return (viewModel, toast)
    }

    /// Four clips of 4 s, a second cut out between each two, the second picked.
    private func cutIntoFour(_ viewModel: QuickEditViewModel) {
        viewModel.changeEdit {
            $0.timeline = EditTimeline(sourceDuration: 20, keeping: [0, 5, 10, 15].map { TimeSpan(start: $0, end: $0 + 4) })
        }
        viewModel.selection = .clip(viewModel.edit.timeline.segments[1].id)
    }

    @Test func oneSwitchPunchesInOnEveryOtherClipInOneUndoStep() async throws {
        let (viewModel, toast) = await makeViewModel()
        #expect(!viewModel.clips.canPunchInOnCuts)
        cutIntoFour(viewModel)
        let steps = viewModel.document.history.past.count
        viewModel.clips.setPunchesInOnCuts(true)
        #expect(viewModel.edit.cutZoom == CutZoom(strength: .medium))
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(toast.message == "Punch in on 2 clips")
        #expect(toast.action?.title == "Undo")
        // The clips themselves are untouched: the switch is drawn, so it follows the cuts made after it.
        #expect(viewModel.edit.timeline.segments.allSatisfy { $0.zoom == nil })
        #expect(viewModel.edit.punchedTimeline.segments.map(\.punchesInOnCut) == [false, true, false, true])
        // The timeline's badge says where each lands.
        let badges = viewModel.timelineInput(heightClass: .regular).clips.map(\.badge)
        #expect(badges == [nil, SectionZoom.punchIn.label, nil, SectionZoom.punchIn.label])

        viewModel.clips.setCutZoomStrength(.strong)
        #expect(viewModel.edit.cutZoom?.strength == .strong)
        viewModel.undo()
        viewModel.undo()
        #expect(viewModel.edit.cutZoom == nil)
    }

    @Test func aClipZoomedByHandKeepsItsZoomAndSaysSo() async throws {
        let (viewModel, _) = await makeViewModel()
        cutIntoFour(viewModel)
        viewModel.clips.setClipZoom(.pushIn)
        viewModel.clips.setPunchesInOnCuts(true)
        #expect(viewModel.clips.cutZoomClipNote == "This clip keeps the zoom and crop you gave it")
        let punched = viewModel.edit.punchedTimeline.segments
        #expect(punched[1].zoom == .pushIn && !punched[1].punchesInOnCut)
        viewModel.clips.setPunchesInOnCuts(false)
        #expect(viewModel.edit.timeline.segments[1].zoom == .pushIn, "Turning it off leaves the creator's zoom")
    }

    /// A horizontal 1080p take cropped to 9:16 has about 607 pixels across: Strong (1.25×) stops at 1.12×, and the panel says why.
    @Test func aLowResolutionVideoSaysWhereTheZoomStops() async throws {
        let (viewModel, _) = await makeViewModel()
        viewModel.look.recordingUprightSize = CGSize(width: 1920, height: 1080)
        cutIntoFour(viewModel)
        viewModel.clips.setPunchesInOnCuts(true)
        viewModel.clips.setCutZoomStrength(.strong)
        // 1.12× in the Simulator's number format.
        #expect(viewModel.cutZoomLimitNote == "Zoom stops at \(SpeedScale.label(forMultiple: 1.12)) · the video has too few pixels for more")
        viewModel.clips.setCutZoomStrength(.subtle)
        #expect(viewModel.cutZoomLimitNote == nil)
        viewModel.look.recordingUprightSize = CGSize(width: 1080, height: 1920)
        viewModel.clips.setCutZoomStrength(.strong)
        #expect(viewModel.cutZoomLimitNote == nil)
    }

    // MARK: - Kit

    @Test func theKitKeepsTheZoomAndPutsItOnANewVideo() async throws {
        let kits = Self.kitsStore()
        var source = TakeEdit(sourceDuration: 20, aspect: .portrait)
        source.cutZoom = CutZoom(strength: .strong)
        source.phraseZooms = [PhraseZoom(span: TimeSpan(start: 1, end: 2), strength: .subtle)]
        var kit = BrandKit(name: "Mine")
        kit.editing = BrandKitEditing(of: source)
        #expect(kit.editing?.zoom == BrandKitZoom(cutZoom: CutZoom(strength: .strong), phraseStrength: .subtle))
        #expect(kit.has(.zoom))
        kit.usesOnNewVideos = true
        kits.save(kit)
        let (viewModel, _) = await makeViewModel(kits: kits)
        #expect(viewModel.edit.cutZoom == CutZoom(strength: .strong))
        #expect(viewModel.edit.phraseZoomStrength == .subtle)
        // No phrase is zoomed by it, and nothing else of the source video comes along.
        #expect(viewModel.edit.phraseZooms.isEmpty)
        let change = try #require(viewModel.brand.changes(for: kit).first { $0.part == .zoom })
        #expect(change.detail == "Punch in on cuts: Strong · Phrase zooms: Subtle")
    }

    @Test func kitsSavedBeforeKeepNoZoom() throws {
        let editing = BrandKitEditing(of: TakeEdit(sourceDuration: 20, aspect: .portrait))
        #expect(editing.zoom == nil)
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(editing)) as? [String: Any])
        json.removeValue(forKey: "zoom")
        let read = try JSONDecoder().decode(BrandKitEditing.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(read == editing)
        var kit = BrandKit(name: "Old")
        kit.editing = read
        #expect(!kit.has(.zoom))
    }

    // MARK: - Follow face over imported recordings

    /// An imported horizontal recording with two people, in a montage after the take: Follow face's line says so, and the framing
    /// stays as the creator set it.
    @Test func anImportedVideoWithTwoPeopleIsSaid() async throws {
        let name = "two-people-\(UUID().uuidString).mov"
        let file = EditMediaFiles.url(for: name)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0]).write(to: file)
        defer {
            MotionAnalysisStore.remove(forRecording: file)
            try? FileManager.default.removeItem(at: file)
        }
        var analysis = MotionAnalysis(duration: 6, width: 1920, height: 1080)
        let left = NormalizedBox(center: CGPoint(x: 0.3, y: 0.4), width: 0.12, height: 0.2)
        let right = NormalizedBox(center: CGPoint(x: 0.7, y: 0.4), width: 0.12, height: 0.2)
        analysis.subjects = (0..<60).map { SubjectSample(time: Double($0) / 10, faces: [left, right], bodies: []) }
        analysis.analyzedUntil = 6
        MotionAnalysisStore.save(analysis, forRecording: file)

        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        let source = ClipSource(fileName: name, duration: 6, title: "Video")
        edit.sources = [source]
        edit.timeline.insertClip(source: source.id, duration: 6)
        let (viewModel, _) = await makeViewModel(edit: edit)
        viewModel.look.setFollowsFace(true)
        #expect(viewModel.look.followsFace)
        #expect(viewModel.look.faceFollowNote == FaceFollowLimit.severalFaces.note)
        #expect(viewModel.edit.faceFollow != nil, "The line never turns it off")
        // And no zoom grows toward either of them.
        #expect(FaceZoomFocus.of(analysis) == nil)
    }
}
