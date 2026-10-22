//
//  ScriptStarterTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// An idea sent to the script page: a new empty script and a request waiting on it.
@MainActor
@Suite("Script starter")
struct ScriptStarterTests {
    private struct Scenario {
        let starter: ScriptStarter
        let library: ScriptLibraryService
        let presentation: PresentationService
        let ideaDraft: IdeaDraftService
        let transition: IdeaTransitionService
        let writer: FakeScriptWriter
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario(languages: LanguageService? = nil) -> Scenario {
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now })
        let presentation = PresentationService()
        let ideaDraft = IdeaDraftService()
        let transition = IdeaTransitionService()
        transition.speed = 0.01
        let writer = FakeScriptWriter()
        let toast = ToastService()
        let starter = ScriptStarter(
            library: library, rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            languages: languages ?? TestData.languages(defaults: defaults.defaults), presentation: presentation, ideaDraft: ideaDraft,
            transition: transition, writer: writer, toast: toast
        )
        return Scenario(
            starter: starter, library: library, presentation: presentation, ideaDraft: ideaDraft, transition: transition,
            writer: writer, toast: toast, defaults: defaults
        )
    }

    @Test func theCardsIdeaOpensANewScriptWithItsRequest() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "  Carnival in Salvador "
        scenario.ideaDraft.platform = .reels
        scenario.ideaDraft.format = .review
        scenario.starter.write()
        #expect(scenario.library.scripts.count == 1)
        let script = scenario.library.scripts[0]
        #expect(script.isEmpty && script.platform == .reels && script.type == .review)
        let route = scenario.presentation.scriptsPath.first
        #expect(route?.scriptID == script.id && route?.startsEditing == true)
        #expect(route?.writing?.source == .prompt("Carnival in Salvador"))
        #expect(route?.writing?.format == .review)
        // The card keeps its idea until the script is written (a failed request can be tried again).
        #expect(scenario.ideaDraft.text == "  Carnival in Salvador ")
    }

    @Test func anIdeaFromFindInspirationIsWrittenAsIs() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.starter.write(idea: "1 min list video: 3 things I stopped buying", length: .minute1)
        #expect(scenario.presentation.scriptsPath.first?.writing?.targetRange == 54...66)
    }

    @Test func nothingIsWrittenFromAnEmptyIdea() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "   "
        scenario.starter.write()
        #expect(scenario.library.scripts.isEmpty && scenario.presentation.scriptsPath.isEmpty)
    }

    @Test func theCardsPlatformIsTheChoiceOrTheDefault() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.starter.platform == .tiktok)
        scenario.ideaDraft.platform = .linkedin
        #expect(scenario.starter.platform == .linkedin)
    }

    @Test func theIdeasStarRisesAsTheTransitionAndCancelTakesTheScriptBack() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.starter.write(from: CGPoint(x: 300, y: 700))
        #expect(scenario.transition.isActive && scenario.transition.idea == "Carnival in Salvador")
        #expect(scenario.library.scripts.count == 1 && !scenario.presentation.scriptsPath.isEmpty)
        scenario.transition.cancel()
        // No script is created, the page goes, and the idea is still in the field.
        #expect(scenario.library.scripts.isEmpty && scenario.presentation.scriptsPath.isEmpty)
        #expect(scenario.ideaDraft.text == "Carnival in Salvador")
    }

    @Test func whenTheScriptIsReadyItStaysInTheLibrary() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.starter.write(from: CGPoint(x: 300, y: 700))
        await scenario.transition.contentReady()
        #expect(scenario.library.scripts.count == 1)
    }

    // MARK: - A language Apple Intelligence doesn't write

    private static let thaiIdea = "ทำไมฉันเลิกกินกาแฟสามสิบวันแล้วชีวิตเปลี่ยนไป"

    /// The star doesn't fly only to fall, and no empty draft opens to say it: a language the model can't draft in is told at once, in a
    /// toast with "Write it", and the idea stays in the field.
    @Test func anIdeaInALanguageTheModelCannotDraftOpensNothingAndStaysInTheField() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.writer.languagesNotWritten = ["th"]
        scenario.ideaDraft.text = Self.thaiIdea
        #expect(scenario.starter.write() == nil)
        #expect(scenario.library.scripts.isEmpty)
        #expect(scenario.presentation.scriptsPath.isEmpty)
        #expect(!scenario.transition.isActive)
        #expect(scenario.ideaDraft.text == Self.thaiIdea)
        #expect(scenario.toast.message == DraftingAvailability.Cause.languageNotSupported(.thai).reason)
        #expect(scenario.toast.action?.title == String(localized: "Write it"))
    }

    /// "Write it" in the toast is the creator's choice: the idea becomes the title of a blank draft, opened to write in, and leaves the dock.
    @Test func writeItInTheToastOpensTheCreatorsBlankDraft() throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.writer.languagesNotWritten = ["th"]
        scenario.ideaDraft.text = Self.thaiIdea
        scenario.starter.write()
        try #require(scenario.toast.action).perform()
        #expect(scenario.library.scripts.count == 1)
        #expect(scenario.library.scripts.first?.title == Self.thaiIdea)
        #expect(scenario.presentation.scriptsPath.first?.writing == nil)
        #expect(scenario.presentation.scriptsPath.first?.startsEditing == true)
        #expect(scenario.ideaDraft.text.isEmpty)
    }

    /// An idea from elsewhere (the Logbook, Find inspiration) written by hand leaves the creator's own draft in the dock, and tells the caller
    /// it became a script.
    @Test func writeItForAnIdeaFromElsewhereKeepsTheDocksDraft() throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.writer.languagesNotWritten = ["th"]
        scenario.ideaDraft.text = "My own idea in the dock"
        var written: UUID?
        scenario.starter.write(idea: Self.thaiIdea) { written = $0 }
        try #require(scenario.toast.action).perform()
        #expect(written != nil && written == scenario.library.scripts.first?.id)
        #expect(scenario.ideaDraft.text == "My own idea in the dock")
    }

    /// Every cause is told the same way, before the star, with its own words.
    @Test(arguments: [AIPlanFailure.deviceNotSupported, .turnedOff, .modelPreparing])
    func whatAppleIntelligenceCantDoIsToldBeforeTheStar(_ failure: AIPlanFailure) {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.writer.writingFailureToReturn = failure
        scenario.ideaDraft.text = "Carnival in Salvador"
        #expect(scenario.starter.write() == nil)
        #expect(scenario.library.scripts.isEmpty && !scenario.transition.isActive)
        #expect(scenario.toast.message == DraftingAvailability.Cause(failure).reason)
    }

    @Test func cuesOwnSwitchOffIsToldBeforeTheStar() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.writer.isEnabled = false
        scenario.ideaDraft.text = "Carnival in Salvador"
        #expect(scenario.starter.write() == nil)
        #expect(scenario.toast.message == AIAvailability.turnedOffReason)
    }

    // MARK: - Told before the idea is sent

    /// A Script Language the model doesn't write is known before anything is typed; on Auto-detect the dock says nothing about a language
    /// (the idea's own is known only when it is sent), and never guesses with the interface's.
    @Test func theDockKnowsAScriptLanguageButNeverGuessesOnAuto() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let languages = TestData.languages(defaults: defaults.defaults, appLanguage: "th")
        let scenario = makeScenario(languages: languages)
        defer { scenario.defaults.tearDown() }
        scenario.writer.languagesNotWritten = ["th"]
        #expect(scenario.starter.dockDrafting.isAvailable)
        #expect(scenario.starter.drafting(before: "hi").isAvailable)
        #expect(scenario.starter.drafting(before: Self.thaiIdea) == .unavailable(.languageNotSupported(.thai)))
        languages.scriptLanguage = .thai
        #expect(scenario.starter.dockDrafting == .unavailable(.languageNotSupported(.thai)))
        #expect(scenario.starter.drafting(before: "Carnival in Salvador") == .unavailable(.languageNotSupported(.thai)))
    }

    /// An answered comment is drafted in the comment's language, not in the English Cue wraps it in.
    @Test func anAnsweredCommentIsReadInItsOwnLanguage() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let comment = ScriptComment(author: "@maya", text: "Você acorda cedo todo dia mesmo ou é só pros vídeos?", platform: .tiktok)
        let request = scenario.starter.factory.request(
            idea: AnswerCommentViewModel.idea(for: comment), platform: .tiktok, format: nil, languageText: comment.text
        )
        #expect(request.language == .portugueseBrazil)
    }

    // MARK: - A late failure

    /// Apple Intelligence changed while the star rose: the reply couldn't be drafted, and the comment (whose sheet is gone) is kept.
    /// Cancel keeps nothing: the creator chose it.
    @Test func aCommentWhoseReplyFailedLateIsKeptAndCancelKeepsNothing() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        var kept: [ScriptComment] = []
        scenario.starter.keepsComment = { kept.append($0) }
        let comment = ScriptComment(author: "@maya", text: "Do you ever skip the gym?", platform: .tiktok)
        scenario.starter.write(idea: AnswerCommentViewModel.idea(for: comment), comment: comment)
        scenario.transition.fail()
        #expect(kept == [comment])
        #expect(scenario.library.scripts.isEmpty)
        scenario.starter.write(idea: AnswerCommentViewModel.idea(for: comment), comment: comment)
        scenario.transition.cancel()
        #expect(kept.count == 1)
    }

    @Test func aSupportedLanguageStillGoesToTheModel() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.starter.write()
        #expect(scenario.presentation.scriptsPath.first?.writing != nil)
        #expect(scenario.toast.message == nil)
    }
}
