//
//  QuickEditCaptionStyleGalleryTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Caption style after the owner's canvas 2 (F1, F2): All has no empty Mine on top and "Save style" is the last card of its
/// gallery; Styles opens on the section of the style the captions wear; Custom's "Choose words to emphasize" opens the line
/// under the playhead in Captions and ✓ (or ‹ Style) comes back to Caption style on the same tab, scroll, playhead and pick;
/// Reset's toast names what came back.
@MainActor
@Suite("Quick edit caption style gallery")
struct QuickEditCaptionStyleGalleryTests {
    private func makeViewModel(styles: FakeTextStyleStore = FakeTextStyleStore()) async -> (QuickEditViewModel, FakeEditPlayback) {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: styles
        )
        await viewModel.prepare()
        return (viewModel, player)
    }

    private func lines(_ viewModel: QuickEditViewModel) -> [CaptionCue] {
        let lines = [
            CaptionCue(text: "Okay real talk", start: 1, end: 2.5, origin: .manual),
            CaptionCue(text: "this changed my mornings", start: 4, end: 6, origin: .manual),
        ]
        viewModel.changeEdit { $0.captions = lines }
        viewModel.captions.pickCaptionTheme(.cue)
        return lines
    }

    // MARK: - The gallery

    @Test func withNoStyleOfTheirOwnAllHasNoMineAndEndsWithSaveStyle() async {
        let (viewModel, _) = await makeViewModel()
        _ = lines(viewModel)
        let all = viewModel.captions.captionCardSections(.all)
        #expect(!all.contains { $0.isMine }, "an empty Mine on top of All")
        #expect(all.filter(\.endsWithSave).map(\.id) == [all.last?.id], "Save style is All's last card, once")
        #expect(all.last?.title == CaptionCategory.allCases.last?.label)
        #expect(viewModel.captions.captionCardSections(.mine).first?.endsWithSave == true, "Mine's gallery ends with Save style too")
        #expect(viewModel.captions.captionCardSections(.category(.impact)).allSatisfy { !$0.endsWithSave })
        #expect(viewModel.captions.captionCardSections(.favorites).allSatisfy { !$0.endsWithSave })
    }

    @Test func onceSavedMineIsInAllAndSaveStyleEndsIt() async {
        let (viewModel, _) = await makeViewModel()
        _ = lines(viewModel)
        viewModel.captions.saveCaptionStyle(named: "Weekly")
        let all = viewModel.captions.captionCardSections(.all)
        let mine = all.firstIndex(where: \.isMine)
        #expect(mine != nil, "Mine shows once it has a style")
        #expect(all.filter(\.endsWithSave).count == 1)
        #expect(mine.map { all[$0].endsWithSave } == true, "Save style ends Mine, not the catalogue")
        #expect(mine.map { all[$0].cards.map(\.name) } == ["Weekly"])
    }

    /// Styles opens on what the captions wear: a style of a later group brings its group to the top; one of the first group (or
    /// this video's own look, always first) keeps the top, with Size and the filters.
    @Test func stylesOpensOnTheSectionOfTheStyleTheCaptionsWear() async {
        let (viewModel, _) = await makeViewModel()
        _ = lines(viewModel)
        #expect(viewModel.captions.captionRevealedSection(.all) == nil, "Cue is in the first group")
        viewModel.captions.pickCaptionTheme(.comic)
        #expect(viewModel.captions.captionRevealedSection(.all) == CaptionCategory.impact.label)
        #expect(viewModel.captions.captionRevealedSection(.category(.impact)) == nil, "one section: the top")
        viewModel.captions.setCaptionEntry(.rise)
        #expect(viewModel.captions.currentCaptionCard != nil)
        #expect(viewModel.captions.captionRevealedSection(.all) == nil, "this video's own look is first")
    }

    // MARK: - Choose words to emphasize

    @Test func chooseWordsOpensTheLineUnderThePlayheadAndComesBackToTheSamePoint() async throws {
        let (viewModel, player) = await makeViewModel()
        let made = lines(viewModel)
        player.seek(to: 4.8)
        viewModel.panel = .captionStyle
        viewModel.panelTab = .adjust
        #expect(viewModel.captions.canChooseWordsToEmphasize)

        viewModel.captions.chooseWordsToEmphasize(from: .adjust, offset: 240)
        let second = try #require(viewModel.captions.captionListLines.first { $0.line.text == made[1].text })
        #expect(viewModel.panel == .captions)
        #expect(viewModel.selection == .caption(second.cueID))
        #expect(viewModel.captions.expandedLineID == second.cueID, "its words to emphasize open")
        #expect(player.currentTime == 4.8, "the line is under the playhead: it stays")
        viewModel.captions.toggleCaptionEmphasis(second.cueID, word: 1)
        #expect(player.currentTime == 4.8, "marking a word of the line under the playhead leaves the playhead")

        viewModel.closePanel()
        #expect(viewModel.panel == .captionStyle, "✓ goes back to Caption style")
        #expect(viewModel.panelTab == .adjust)
        #expect(viewModel.captions.restoresCustomOffset && viewModel.captions.captionCustomOffset == 240, "Custom where it was")
        #expect(viewModel.selection == nil, "nothing was picked before")
        #expect(player.currentTime == 4.8)
        #expect(viewModel.captions.styleReturn == nil)
        #expect(viewModel.edit.captions.first { $0.id == second.cueID }?.emphasis == [1], "the word stays marked")

        viewModel.closePanel()
        #expect(viewModel.panel == nil, "then ✓ closes Caption style")
    }

    @Test func betweenLinesTheNextLineOpensAndThePlayheadComesBack() async throws {
        let (viewModel, player) = await makeViewModel()
        let made = lines(viewModel)
        player.seek(to: 3)
        viewModel.panel = .captionStyle
        viewModel.panelTab = .adjust
        viewModel.captions.chooseWordsToEmphasize(from: .adjust, offset: 0)
        let second = try #require(viewModel.captions.captionListLines.first { $0.line.text == made[1].text })
        #expect(viewModel.selection == .caption(second.cueID))
        #expect(player.currentTime > 4 && player.currentTime < 4.1, "the playhead goes to the line it opens")
        #expect(viewModel.captions.returnToCaptionStyle())
        #expect(player.currentTime == 3, "and back where it was")
        #expect(viewModel.captions.restoresCustomOffset == true)
    }

    /// A playhead a frame short of a line's start (where tapping the line can land it) is on that line: it doesn't move.
    @Test func aFrameShortOfALineIsOnIt() async throws {
        let (viewModel, player) = await makeViewModel()
        let made = lines(viewModel)
        player.seek(to: 3.98)
        viewModel.panel = .captionStyle
        viewModel.panelTab = .adjust
        viewModel.captions.chooseWordsToEmphasize(from: .adjust, offset: 0)
        let second = try #require(viewModel.captions.captionListLines.first { $0.line.text == made[1].text })
        #expect(viewModel.selection == .caption(second.cueID))
        #expect(player.currentTime == 3.98, "the playhead stays")
    }

    /// Leaving Captions another way just leaves: ✓ then closes Captions, as always.
    @Test func leavingCaptionsAnotherWayDropsTheWayBack() async {
        let (viewModel, player) = await makeViewModel()
        _ = lines(viewModel)
        player.seek(to: 1.5)
        viewModel.panel = .captionStyle
        viewModel.panelTab = .adjust
        viewModel.captions.chooseWordsToEmphasize(from: .adjust, offset: 0)
        #expect(viewModel.captions.styleReturn != nil)
        viewModel.panel = .speed
        #expect(viewModel.captions.styleReturn == nil)
        #expect(viewModel.captions.expandedLineID == nil)
        viewModel.panel = .captions
        viewModel.closePanel()
        #expect(viewModel.panel == nil)
        #expect(!viewModel.captions.returnToCaptionStyle())
    }

    @Test func withoutLinesThereIsNoLineToOpen() async {
        let (viewModel, _) = await makeViewModel()
        _ = lines(viewModel)
        viewModel.changeEdit { $0.captions = [] }
        #expect(!viewModel.captions.canChooseWordsToEmphasize)
        viewModel.panel = .captionStyle
        viewModel.captions.chooseWordsToEmphasize(from: .adjust, offset: 0)
        #expect(viewModel.panel == .captionStyle)
    }

    // MARK: - Reset's reach

    @Test func resetSaysWhatCameBackWithUndo() async {
        let (viewModel, _) = await makeViewModel()
        _ = lines(viewModel)
        viewModel.captions.setCaptionPointSize(26)
        viewModel.captions.resetCaptionTheme()
        #expect(viewModel.session.toast.message == String(localized: "Back to the whole \(CaptionTheme.cue.label) style: look, size and position"))
        #expect(viewModel.captions.captionPointSize != 26)
        viewModel.session.toast.dismiss()
        viewModel.captions.resetCaptionTheme()
        #expect(viewModel.session.toast.message == nil, "nothing came back: nothing to say")
    }
}
