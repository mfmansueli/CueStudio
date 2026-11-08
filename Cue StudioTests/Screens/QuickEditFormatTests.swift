//
//  QuickEditFormatTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Aspect ratio (F16): Reset back to the video as recorded, in one undo step; Follow face's note offers only formats with room (bug 11),
/// and never turns it on; the file's real size when the crop makes it smaller.
@MainActor
@Suite("Quick edit · Aspect ratio")
struct QuickEditFormatTests {
    private func makeViewModel() async -> QuickEditViewModel {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return viewModel
    }

    @Test func resetGoesBackToTheRecordingInOneUndoStep() async {
        let viewModel = await makeViewModel()
        #expect(viewModel.edit.aspect == .portrait)
        #expect(viewModel.panelReset(.crop) == nil)
        viewModel.look.setAspect(.square)
        viewModel.look.setFollowsFace(true)
        viewModel.look.setAspect(.landscape)
        viewModel.look.setCropFit(.fit)
        viewModel.look.moveCrop(to: 0.4)
        let reset = viewModel.panelReset(.crop)
        #expect(reset != nil)
        reset?()
        #expect(viewModel.edit.aspect == .portrait)
        #expect(viewModel.edit.cropFit == .fill)
        #expect(viewModel.edit.cropOffset == 0)
        #expect(viewModel.edit.faceFollow == nil)
        #expect(viewModel.panelReset(.crop) == nil)
        // One step: Undo brings the whole format back.
        viewModel.undo()
        #expect(viewModel.edit.aspect == .landscape)
        #expect(viewModel.edit.cropFit == .fit)
        #expect(viewModel.edit.cropOffset == 0.4)
        #expect(viewModel.edit.faceFollow != nil)
    }

    /// Picking a format that crops never turns Follow face on, even from a landscape recording to vertical (owner, 07/11/2026).
    @Test func followFaceOnlyTurnsOnByTheCreatorsChoice() async {
        let viewModel = await makeViewModel()
        viewModel.look.recordingUprightSize = CGSize(width: 1920, height: 1080)
        viewModel.look.setAspect(.landscape)
        viewModel.look.setAspect(.portrait)
        #expect(viewModel.look.canFollowFace)
        #expect(!viewModel.look.followsFace)
        #expect(viewModel.look.faceFollowNote == nil)
    }

    /// Bug 11: with no room, the note offers the formats other than the recording's own (the one picked), whatever the recording.
    @Test func theNoRoomNoteNeverOffersThePickedFormat() async {
        let portrait = await makeViewModel()
        #expect(!portrait.look.canFollowFace)
        let fromPortrait = portrait.look.faceFollowNote ?? ""
        for offered in ["4:5", "1:1", "16:9"] { #expect(fromPortrait.contains(offered), "\(offered)") }
        #expect(!fromPortrait.contains("9:16"))

        let landscape = await makeViewModel()
        landscape.look.recordingUprightSize = CGSize(width: 1920, height: 1080)
        landscape.look.setAspect(.landscape)
        #expect(!landscape.look.canFollowFace)
        let fromLandscape = landscape.look.faceFollowNote ?? ""
        for offered in ["9:16", "4:5", "1:1"] { #expect(fromLandscape.contains(offered), "\(offered)") }
        #expect(!fromLandscape.contains("16:9"))

        // Fit has no room in any format: it says Fill.
        landscape.look.setAspect(.portrait)
        landscape.look.setCropFit(.fit)
        #expect(landscape.look.faceFollowNote == "Follow face works with Fill")
    }

    @Test func theFormatsWithRoomAreEveryOneButTheRecordingsShape() {
        for recorded in AspectRatio.allCases {
            let offered = LookViewModel.formatsWithRoom(recordingAspect: recorded.widthOverHeight)
            #expect(offered == AspectRatio.allCases.filter { $0 != recorded })
        }
        // A recording of another shape (4:3) has room in every format.
        #expect(LookViewModel.formatsWithRoom(recordingAspect: 4.0 / 3.0) == AspectRatio.allCases)
    }

    /// The panel says the file's real size by the review's rule, only when the crop makes it smaller.
    @Test func theRealSizeShowsWhenTheCropReducesIt() async {
        let viewModel = await makeViewModel()
        #expect(viewModel.look.exportSizeNote == nil)
        viewModel.look.reducedExportSize = { $0.aspect == .portrait ? CGSize(width: 606, height: 1080) : nil }
        #expect(viewModel.look.exportSizeNote == "This format exports at 606×1080 · never enlarged")
        viewModel.look.setAspect(.landscape)
        #expect(viewModel.look.exportSizeNote == nil)
    }
}
