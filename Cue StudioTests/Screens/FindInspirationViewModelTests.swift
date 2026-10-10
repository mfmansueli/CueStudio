//
//  FindInspirationViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Find inspiration: the filters it offers, what the card shows, "Another idea", and "Start with it" with its Undo.
@MainActor
@Suite("Find inspiration")
struct FindInspirationViewModelTests {
    private struct Rig {
        let model: FindInspirationViewModel
        let suggestions: IdeaSuggestionService
        let draft: IdeaDraftService
        let profile: CreatorProfileService
        let writer: FakeScriptWriter
        let defaults: TestDefaults
    }

    /// Without a model (the starters only), unless `available`.
    private func rig(available: Bool = false, profile edit: (inout CreatorProfile) -> Void = { _ in }) -> Rig {
        let defaults = TestDefaults()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        var created = profile.profile
        edit(&created)
        profile.profile = created
        let writer = FakeScriptWriter()
        if !available { writer.availability = AIAvailability(onDevice: false, privateCloud: false, reason: "Off") }
        let suggestions = IdeaSuggestionService(writer: writer, profile: profile, interfaceLanguage: { .english }, defaults: defaults.defaults)
        let draft = IdeaDraftService()
        let model = FindInspirationViewModel(suggestions: suggestions, draft: draft, profile: profile)
        return Rig(model: model, suggestions: suggestions, draft: draft, profile: profile, writer: writer, defaults: defaults)
    }

    /// Lets the model's answers (or failures) arrive.
    private func settle(_ rig: Rig) async {
        for _ in 0..<200 {
            await Task.yield()
            if !rig.suggestions.isRefilling { try? await Task.sleep(for: .milliseconds(2)) }
        }
    }

    private func briefIdea() -> ThemeIdea {
        var idea = ThemeIdea(title: "Why saving feels harder than spending", kind: "Explainer", length: .minute1, niche: .finance)
        idea.brief = IdeaBrief(
            subject: "Saving", angle: "one small habit that makes it easier",
            openingLine: "Saving isn't about willpower.", subtopic: "Budgeting"
        )
        return idea
    }

    // MARK: - Filters

    @Test func theFiltersAreAllMyTopicsThenEveryTopicTheCreatorHoldsInOrder() {
        let rig = rig { profile in
            profile.niches = [.finance, .fitness]
            profile.customTopics = ["Daily Routine"]
        }
        defer { rig.defaults.tearDown() }
        let options = rig.model.options
        #expect(options.map(\.id) == ["all", "finance", "fitness", "custom.daily-routine"])
        #expect(options.first?.label == nil)
        #expect(options.dropFirst().map(\.label) == [Niche.finance.chipLabel, Niche.fitness.chipLabel, "Daily Routine"])
        #expect(options.map(\.worldIndex) == [nil, 0, 1, 2])
    }

    @Test func aTopicHeldTwiceIsOneChip() {
        let topics = [
            IdeaTopic(name: "Daily Routine", label: "Daily Routine"), IdeaTopic(name: "daily routine", label: "daily routine"),
        ]
        #expect(InspirationFilterOption.options(for: topics).map(\.id) == ["all", "custom.daily-routine"])
    }

    @Test func withNoTopicsThereIsOnlyAllMyTopicsAndStillAnIdea() {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        #expect(!rig.model.hasTopics)
        #expect(rig.model.options.map(\.id) == ["all"])
        #expect(rig.model.idea?.niche == .lifestyle, "general starters while no topic is chosen")
    }

    @Test func choosingATopicShowsAnIdeaAboutIt() {
        let rig = rig { $0.niches = [.finance, .food] }
        defer { rig.defaults.tearDown() }
        let food = rig.model.options.first { $0.id == "food" }!
        rig.model.select(food)
        #expect(rig.model.selectedOptionID == "food")
        #expect(rig.model.idea?.niche == .food)
    }

    @Test func aTypedTopicWithoutAModelStillHasStartersAboutIt() {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.model.select(rig.model.options.first { $0.id == "custom.daily-routine" }!)
        guard case .idea(let idea) = rig.model.content else { Issue.record("no starter about a typed topic"); return }
        #expect(rig.model.card(for: idea).category.contains("Daily Routine"))
        #expect(!rig.model.isFindingMore && !rig.model.couldNotFindMore)
    }

    @Test func whenTheIdeasDontComeTheSheetSaysSoAndTryAgainAsksAgain() async {
        let rig = rig(available: true) { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.error = ScriptAIError.rateLimited
        rig.model.select(rig.model.options.first { $0.id == "custom.daily-routine" }!)
        // Through the starters about the topic, to the end of what is ready: the model's ideas fail.
        for _ in 0..<20 {
            guard rig.model.idea != nil, !rig.model.isFindingMore, !rig.model.couldNotFindMore else { break }
            rig.model.another()
            await settle(rig)
        }
        await Wait.until { rig.model.couldNotFindMore || rig.model.content == .failed }
        #expect(rig.model.couldNotFindMore || rig.model.content == .failed)
        rig.writer.error = nil
        rig.model.retry()
        #expect(!rig.model.couldNotFindMore && rig.model.content != .failed)
    }

    @Test func aTopicTheCreatorDropsFallsBackToAllMyTopics() {
        let rig = rig { $0.niches = [.finance, .food] }
        defer { rig.defaults.tearDown() }
        rig.model.select(rig.model.options.first { $0.id == "food" }!)
        rig.profile.profile.niches = [.finance]
        rig.model.topicsChanged()
        #expect(rig.model.selectedOptionID == "all")
        #expect(rig.model.filter == .all)
    }

    // MARK: - Another idea

    @Test func anotherIdeaChangesTheCardAndCountsATurn() {
        let rig = rig { $0.niches = [.finance] }
        defer { rig.defaults.tearDown() }
        rig.model.select(rig.model.options.first { $0.id == "finance" }!)
        let first = rig.model.idea
        rig.model.another()
        #expect(rig.model.idea != nil)
        #expect(rig.model.idea != first)
        #expect(rig.model.turn == 1)
    }

    @Test func anotherIdeaWithNothingShownDoesNothing() async {
        let rig = rig(available: true) { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.holdsSuggestions = true
        rig.model.select(rig.model.options.first { $0.id == "custom.daily-routine" }!)
        guard rig.model.idea == nil else { return }
        rig.model.another()
        #expect(rig.model.turn == 0)
        rig.writer.holdsSuggestions = false
    }

    // MARK: - Start with it

    @Test func usingAnIdeaInAnEmptyComposerPutsTheWholeBriefThereAndOffersNoUndo() {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        let idea = briefIdea()
        let replaced = rig.model.use(idea)
        #expect(!replaced)
        #expect(rig.draft.text == idea.brief?.composerText)
        #expect(rig.draft.text.contains("Saving") && rig.draft.text.contains("one small habit") && rig.draft.text.contains("willpower"))
        #expect(rig.draft.brief == idea.brief)
    }

    @Test func usingAnIdeaOverTheCreatorsWordsOffersUndoAndUndoBringsThemBack() {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        rig.draft.text = "my own half idea"
        let replaced = rig.model.use(briefIdea())
        #expect(replaced)
        #expect(rig.draft.text != "my own half idea")
        rig.model.undoUse()
        #expect(rig.draft.text == "my own half idea")
        #expect(rig.draft.brief == nil)
    }

    @Test func editingTheBriefAfterUsingItKeepsWhatStillStands() {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        rig.model.use(briefIdea())
        rig.draft.text = "Saving: for students\nOpen with: “Saving isn't about willpower.”"
        #expect(rig.draft.submittedBrief?.subject == "Saving")
        #expect(rig.draft.submittedBrief?.angle.isEmpty == true, "the angle the creator changed is not sent")
        #expect(rig.draft.submittedBrief?.openingLine == "Saving isn't about willpower.")
    }

    @Test func anIdeaWithoutABriefIsUsedByItsTitle() {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        let idea = ThemeIdea(title: "3 things I stopped buying this year", kind: "List", length: .minute1, niche: .lifestyle)
        rig.model.use(idea)
        #expect(rig.draft.text == idea.title)
        #expect(FindInspirationViewModel.writingText(of: idea) == idea.prompt)
    }

    // MARK: - The card

    @Test func theCardReadsTopicSubtopicAndKindThenTitleAngleAndOpening() {
        let card = InspirationCardContent(
            idea: briefIdea(), topics: [IdeaTopic(name: "personal finance", label: "Personal finance", niche: .finance)], logbookLabel: "Logbook"
        )
        #expect(card.category == "Personal finance · Budgeting · Explainer")
        #expect(card.title == "Why saving feels harder than spending")
        #expect(card.angle == "one small habit that makes it easier")
        #expect(card.openingLine == "Saving isn't about willpower.")
        #expect(card.hasBrief)
    }

    @Test func theCardDrawsItsOwnQuotesAndLeavesOutWhatIsNotThere() {
        var idea = ThemeIdea(title: "Desk stretches", kind: "", length: .minute1, niche: .fitness)
        idea.brief = IdeaBrief(subject: "Desk stretches", angle: " ", openingLine: "“Your back hurts by 3 p.m.?”", subtopic: "fitness & wellness")
        let card = InspirationCardContent(idea: idea, topics: [], logbookLabel: "Logbook")
        #expect(card.openingLine == "Your back hurts by 3 p.m.?")
        #expect(card.angle == nil)
        #expect(card.category == Niche.fitness.chipLabel, "an empty kind and a subtopic that repeats the topic are left out")
    }

    @Test func aNoteFromTheLogbookSaysWhereItCameFrom() {
        var idea = ThemeIdea(title: "film the market at dawn", kind: "", length: .minute1, niche: .lifestyle)
        idea.logbookID = UUID()
        let card = InspirationCardContent(idea: idea, topics: [], logbookLabel: "From your Logbook")
        #expect(card.isLogbookNote)
        #expect(card.category == "From your Logbook")
        #expect(!card.hasBrief)
        #expect(FindInspirationViewModel.writingText(of: idea) == "film the market at dawn")
    }
}
