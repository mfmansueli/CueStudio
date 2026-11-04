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
            library: library, profile: CreatorProfileService(defaults: defaults.defaults),
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

    /// "Write it myself" on a comment, or Write on an idea of the Logbook without Apple Intelligence: the draft opens named after it, and what
    /// the creator was typing in the dock (and its chips) stays. The dock's own idea written by hand leaves it, as before.
    @Test func writingAnotherIdeaByHandLeavesTheDockAlone() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "My own idea in the dock"
        scenario.ideaDraft.platform = .youtube
        let id = scenario.starter.writeByHand(idea: "A comment to answer")
        #expect(scenario.library.script(id: id)?.title == "A comment to answer")
        #expect(scenario.library.script(id: id)?.isFinished == false)
        #expect(scenario.ideaDraft.text == "My own idea in the dock" && scenario.ideaDraft.platform == .youtube)
        scenario.starter.writeByHand()
        #expect(scenario.library.scripts.first?.title == "My own idea in the dock")
        #expect(scenario.ideaDraft.isEmpty && scenario.ideaDraft.platform == nil)
    }

    /// The script made for the AI to write into says so until its words arrive: a Cue closed under the star leaves no empty "Untitled".
    @Test func theScriptMadeForTheAIWaitsForItsWords() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.starter.write()
        #expect(scenario.library.scripts.first?.awaitsDraft == true)
        // A blank draft the creator opens is theirs from the start.
        scenario.starter.newBlank(platform: .reels)
        #expect(scenario.library.scripts.first?.awaitsDraft == false && scenario.library.scripts.first?.platform == .reels)
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

    // MARK: - The dock's idea and choices (A17, A23)

    /// The dock's own idea: it stays in the dock while the script is written, and the dock starts over only once the script is saved.
    @Test func theDocksIdeaLeavesTheDockOnlyOnceItsScriptIsSaved() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.ideaDraft.platform = .youtube
        scenario.starter.write()
        #expect(scenario.presentation.scriptsPath.first?.writing?.platform == .youtube)
        #expect(scenario.ideaDraft.text == "Carnival in Salvador", "Still there while it is written")
        await scenario.transition.contentReady()
        #expect(scenario.ideaDraft.isEmpty)
        #expect(scenario.ideaDraft.platform == nil)
    }

    /// A dock changed while its last idea was written is a new idea: the script arriving never wipes it.
    @Test func aDockChangedMeanwhileIsNeverWiped() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.starter.write()
        scenario.ideaDraft.text = "Next: winter in Gramado"
        await scenario.transition.contentReady()
        #expect(scenario.ideaDraft.text == "Next: winter in Gramado")
    }

    /// An idea from elsewhere (the Logbook here) is written with the creator's defaults, not the dock's choices, and leaves the dock as it is.
    @Test func anIdeaFromElsewhereNeitherUsesNorClearsTheDock() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "my own half idea"
        scenario.ideaDraft.platform = .youtube
        scenario.ideaDraft.formatChoice = .type(.tutorial)
        scenario.starter.write(idea: "Why I stopped posting daily")
        let request = scenario.presentation.scriptsPath.first?.writing
        #expect(request?.platform == scenario.starter.defaultPlatform)
        #expect(request?.format == nil)
        await scenario.transition.contentReady()
        #expect(scenario.ideaDraft.text == "my own half idea")
        #expect(scenario.ideaDraft.platform == .youtube)
        #expect(scenario.ideaDraft.formatChoice == .type(.tutorial))
    }

    /// An idea on the dock's card (the field empty) follows the dock's choices, which start over once its script is saved.
    @Test func anIdeaOnTheDocksCardFollowsAndThenResetsItsChoices() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.platform = .youtube
        scenario.starter.write(idea: "A card's idea", fromDock: true)
        #expect(scenario.presentation.scriptsPath.first?.writing?.platform == .youtube)
        await scenario.transition.contentReady()
        #expect(scenario.ideaDraft.platform == nil)
    }

    /// The dock is kept on disk as it changes, its choices with it, with no expiry: Cue closed and opened again finds it; once it is cleared,
    /// nothing is left to come back.
    @Test func theDockIsKeptAcrossLaunchesWithItsChoices() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let dock = IdeaDraftService(defaults: defaults.defaults)
        dock.text = "Carnival in Salvador"
        dock.platform = .youtube
        dock.length = .minutes2
        dock.formatChoice = .type(.tutorial)
        let reopened = IdeaDraftService(defaults: defaults.defaults)
        #expect(reopened.text == "Carnival in Salvador")
        #expect(reopened.platform == .youtube)
        #expect(reopened.length == .minutes2)
        #expect(reopened.formatChoice == .type(.tutorial))
        reopened.clear()
        #expect(defaults.defaults.data(forKey: DefaultsKey.dockDraft) == nil)
        #expect(IdeaDraftService(defaults: defaults.defaults).snapshot.isEmpty)
    }

    // MARK: - A late failure

    /// An answered comment is in the Logbook before the star rises (its sheet is gone): a late failure or a Cancel leaves it there, and the
    /// toast says so; a second try is the same note, never a copy; the reply written lets the note made for it go.
    @Test func anAnsweredCommentIsKeptBeforeTheStarAndLetGoOnceWritten() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let logbook = LogbookService(defaults: scenario.defaults.defaults)
        scenario.starter.keepsComment = { logbook.keep($0) }
        scenario.starter.commentAnswered = { logbook.answered($0, as: $1) }
        let comment = ScriptComment(author: "@maya", text: "Do you ever skip the gym?", platform: .tiktok)

        scenario.starter.write(idea: AnswerCommentViewModel.idea(for: comment), comment: comment)
        #expect(logbook.waiting.map(\.text) == ["@maya: Do you ever skip the gym?"], "Kept before anything is asked of it")
        scenario.transition.fail()
        #expect(scenario.library.scripts.isEmpty)
        #expect(scenario.toast.message?.hasSuffix("Saved to Logbook") == true)

        scenario.starter.write(idea: AnswerCommentViewModel.idea(for: comment), comment: comment)
        scenario.transition.cancel()
        #expect(logbook.waiting.count == 1, "The same note, not a copy")
        #expect(scenario.toast.message == "Saved to Logbook")

        // Written this time: the note was already waiting, so it is shaped into the script.
        let id = try #require(scenario.starter.write(idea: AnswerCommentViewModel.idea(for: comment), comment: comment))
        await scenario.transition.contentReady()
        #expect(logbook.waiting.isEmpty)
        #expect(logbook.entries.first?.shapedScriptID == id)
    }

    /// A comment answered at the first try: its note goes with the reply written (the comment is on the script).
    @Test func aCommentAnsweredAtOnceLeavesNoNote() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let logbook = LogbookService(defaults: scenario.defaults.defaults)
        scenario.starter.keepsComment = { logbook.keep($0) }
        scenario.starter.commentAnswered = { logbook.answered($0, as: $1) }
        let comment = ScriptComment(author: nil, text: "How do you plan a week of posts?", platform: .tiktok)
        scenario.starter.write(idea: AnswerCommentViewModel.idea(for: comment), comment: comment)
        await scenario.transition.contentReady()
        #expect(logbook.entries.isEmpty)
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
