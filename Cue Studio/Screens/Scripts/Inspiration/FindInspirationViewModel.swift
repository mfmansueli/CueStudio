//
//  FindInspirationViewModel.swift
//  Cue Studio
//

import Foundation

/// Find inspiration: one idea at a time about the topic chosen in the filters (all of them, or one), "Another idea" for the next, and the
/// two ways to take one: "Use this idea" puts its brief in the dock's composer to change first (what the field held comes back with Undo),
/// and "Write the script now" writes it as it is. The ideas, their order and what the creator's choices teach are `IdeaSuggestionService`'s;
/// this keeps the filter and says what the card shows.
@MainActor
@Observable
final class FindInspirationViewModel {
    /// What the featured card shows.
    enum Content: Equatable {
        case idea(ThemeIdea)
        /// The first ideas about the chosen topic are on their way and nothing about it is ready yet.
        case waiting
        /// Nothing to show and nothing on its way (the model is unavailable or failed, and the topic has no starters).
        case nothing
    }

    private(set) var filter: IdeaTopicFilter = .all
    /// Goes up each time "Another idea" changes the card: the card's transition follows it.
    private(set) var turn = 0

    private let suggestions: IdeaSuggestionService
    private let draft: IdeaDraftService
    private let profile: CreatorProfileService

    init(suggestions: IdeaSuggestionService, draft: IdeaDraftService, profile: CreatorProfileService) {
        self.suggestions = suggestions
        self.draft = draft
        self.profile = profile
    }

    // MARK: - What it shows

    var topics: [IdeaTopic] { profile.profile.ideaTopics }

    /// The creator has told Cue what they make videos about.
    var hasTopics: Bool { !topics.isEmpty }

    /// "All my topics" and one chip per topic.
    var options: [InspirationFilterOption] { InspirationFilterOption.options(for: topics) }

    /// The chip that is on: the one for the filter, or "All my topics" when its topic is no longer held.
    var selectedOptionID: String {
        let current = InspirationFilterOption(filter: filter, label: nil, worldIndex: nil).id
        return options.contains { $0.id == current } ? current : "all"
    }

    var content: Content {
        if let idea = suggestions.current(in: filter) { return .idea(idea) }
        return suggestions.isWaiting(in: filter) ? .waiting : .nothing
    }

    /// The idea on the card, if there is one.
    var idea: ThemeIdea? {
        if case .idea(let idea) = content { idea } else { nil }
    }

    func card(for idea: ThemeIdea) -> InspirationCardContent {
        InspirationCardContent(idea: idea, topics: topics, logbookLabel: String(localized: "From your Logbook"))
    }

    /// The world colour of the idea's topic (the first one's when it is about none of them).
    func worldIndex(of idea: ThemeIdea) -> Int {
        InspirationFilterOption.worldIndex(of: idea, among: topics) ?? 0
    }

    // MARK: - Actions

    /// The sheet is open: ideas about the chosen topic are made ready.
    func appear() {
        topicsChanged()
        suggestions.prepare(for: filter)
    }

    func select(_ option: InspirationFilterOption) {
        guard option.id != selectedOptionID else { return }
        filter = option.filter
        suggestions.prepare(for: filter)
    }

    /// The creator's topics changed (the topics editor, from the filters): a chosen topic they no longer hold falls back to all of them,
    /// and one whose subtopics changed is asked about as it is now.
    func topicsChanged() {
        guard case .topic(let chosen) = filter else { return }
        let id = InspirationFilterOption(filter: filter, label: nil, worldIndex: nil).id
        if let now = options.first(where: { $0.id == id }), case .topic(let held) = now.filter {
            if held != chosen { filter = .topic(held) }
        } else {
            filter = .all
        }
        suggestions.prepare(for: filter)
    }

    /// "Another idea": the next one comes at once (the shown one counts as passed).
    func another() {
        guard idea != nil else { return }
        suggestions.another(in: filter)
        turn += 1
    }

    /// "Use this idea": its brief goes into the composer to be changed before it is written. Returns whether it took the place of words
    /// the creator had there (they come back with `undoUse()`; an idea never silently replaces the creator's own).
    @discardableResult
    func use(_ idea: ThemeIdea) -> Bool {
        suggestions.selected(idea)
        draft.use(idea)
        return draft.replacedText != nil
    }

    func undoUse() {
        draft.undoUse()
    }

    /// "Write the script now": the idea was picked as it is (the script it becomes is the engine's to count).
    func willWrite(_ idea: ThemeIdea) {
        suggestions.selected(idea)
    }

    /// What is written when the idea is written as it is: its brief; for an idea without one, what the ideas always sent ("1 min list
    /// video: …"), and a note of the creator's own in their words.
    static func writingText(of idea: ThemeIdea) -> String {
        if let brief = idea.brief { return brief.composerText }
        return idea.logbookID == nil ? idea.prompt : idea.title
    }
}
