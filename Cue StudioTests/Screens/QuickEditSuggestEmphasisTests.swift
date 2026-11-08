//
//  QuickEditSuggestEmphasisTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Suggest emphasis in the editor (owner, 08/11/2026): off by default; on, one word in the lines with a clear one, never where the
/// creator marked words; a suggestion taken away never comes back on its own; off takes away only the suggestions; one undo step
/// each; the marks keep what they are through a correction, a split and a join, and in the saved project.
@MainActor
struct QuickEditSuggestEmphasisTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let toast: ToastService
    }

    private let money = CaptionCue(text: "Ganhei R$ 5 mil no primeiro mês", start: 0, end: 2, origin: .manual)
    private let percent = CaptionCue(text: "Meu canal cresceu 300% esse ano", start: 2.5, end: 4.5, origin: .manual)
    private let plain = CaptionCue(text: "Mas valem cada centavo.", start: 5, end: 7, origin: .manual)

    private func makeScenario(lines: [CaptionCue]) async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 30
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: FakeEditPlayback(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.changeEdit {
            $0.captions = lines
            $0.showsCaptions = true
            $0.captionLanguage = .portugueseBrazil
        }
        return Scenario(viewModel: viewModel, toast: toast)
    }

    private func line(_ id: UUID, _ viewModel: QuickEditViewModel) -> CaptionCue? {
        viewModel.edit.captions.first { $0.id == id }
    }

    @Test func offByDefaultOnMarksTheClearWordsOneStep() async throws {
        let scenario = await makeScenario(lines: [money, percent, plain])
        let viewModel = scenario.viewModel
        #expect(!viewModel.edit.suggestsEmphasis)
        let steps = viewModel.document.history.past.count
        viewModel.captions.setSuggestsEmphasis(true)
        #expect(viewModel.edit.suggestsEmphasis)
        #expect(line(money.id, viewModel)?.suggestedEmphasis == [2])
        #expect(line(money.id, viewModel)?.emphasis == [2])
        #expect(line(percent.id, viewModel)?.suggestedEmphasis == [3])
        #expect(line(plain.id, viewModel)?.emphasis.isEmpty == true, "No clear word: no mark")
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(scenario.toast.message == "Emphasis suggested in 2 lines · open a line to review")
        viewModel.undo()
        #expect(!viewModel.edit.suggestsEmphasis)
        #expect(line(money.id, viewModel)?.emphasis.isEmpty == true)
    }

    @Test func aLineTheCreatorMarkedIsLeftAlone() async throws {
        var mine = money
        mine.emphasis = [4]
        let scenario = await makeScenario(lines: [mine, percent])
        scenario.viewModel.captions.setSuggestsEmphasis(true)
        #expect(line(mine.id, scenario.viewModel)?.emphasis == [4])
        #expect(line(mine.id, scenario.viewModel)?.suggestedEmphasis.isEmpty == true)
    }

    @Test func aSuggestionTakenAwayNeverComesBackAndOffKeepsTheCreatorsMarks() async throws {
        let scenario = await makeScenario(lines: [money, percent])
        let viewModel = scenario.viewModel
        viewModel.captions.setSuggestsEmphasis(true)
        // Took the suggestion away in the first line; marked a word by hand in the second.
        viewModel.captions.toggleCaptionEmphasis(money.id, word: 2)
        viewModel.captions.toggleCaptionEmphasis(percent.id, word: 1)
        #expect(line(money.id, viewModel)?.emphasis.isEmpty == true)
        #expect(line(money.id, viewModel)?.declinedEmphasis == [2])

        viewModel.captions.setSuggestsEmphasis(false)
        #expect(line(percent.id, viewModel)?.emphasis == [1], "The creator's mark stays; the suggestion goes")
        #expect(scenario.toast.message == "Suggested emphasis off · your marks stay")

        viewModel.captions.setSuggestsEmphasis(true)
        #expect(line(money.id, viewModel)?.emphasis.isEmpty == true, "Taken away: never again on its own")
        #expect(line(percent.id, viewModel)?.emphasis == [1], "A line with the creator's marks gets no suggestion")

        // Marked by hand, the word taken away is the creator's now.
        viewModel.captions.toggleCaptionEmphasis(money.id, word: 2)
        #expect(line(money.id, viewModel)?.emphasis == [2])
        #expect(line(money.id, viewModel)?.declinedEmphasis.isEmpty == true)
        #expect(line(money.id, viewModel)?.suggestedEmphasis.isEmpty == true)
    }

    @Test func theMarksKeepWhatTheyAreThroughACorrectionASplitAndAJoin() async throws {
        let scenario = await makeScenario(lines: [money])
        let viewModel = scenario.viewModel
        viewModel.captions.setSuggestsEmphasis(true)
        viewModel.captions.setCaptionText(money.id, "Eu ganhei R$ 5 mil no primeiro mês")
        let corrected = try #require(line(money.id, viewModel))
        #expect(corrected.suggestedEmphasis == [3], "The suggestion follows its word")
        #expect(CaptionText.words(in: corrected.text)[3] == "5")

        let (first, second) = try #require(CaptionRevision.split(corrected, beforeWord: 4))
        #expect(first.suggestedEmphasis == [3])
        #expect(second.suggestedEmphasis.isEmpty)
        let joined = CaptionRevision.merged(second, first)
        #expect(joined.suggestedEmphasis == [CaptionText.words(in: second.text).count + 3])

        var declined = corrected
        declined.suggestedEmphasis = []
        declined.emphasis = []
        declined.declinedEmphasis = [3]
        let read = try JSONDecoder().decode(CaptionCue.self, from: JSONEncoder().encode(declined))
        #expect(read.declinedEmphasis == [3], "Saved with the project")
    }

    @Test func turningItOffIsOneStepAndUndoBringsTheSuggestionsBack() async throws {
        let scenario = await makeScenario(lines: [money])
        let viewModel = scenario.viewModel
        viewModel.captions.setSuggestsEmphasis(true)
        viewModel.captions.setSuggestsEmphasis(false)
        #expect(line(money.id, viewModel)?.emphasis.isEmpty == true)
        viewModel.undo()
        #expect(viewModel.edit.suggestsEmphasis)
        #expect(line(money.id, viewModel)?.suggestedEmphasis == [2])
    }
}
