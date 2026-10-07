//
//  GenerationDeadlinesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A request to the model that goes quiet is given up on instead of waiting for ever (measured on an iPhone 15 Pro: the star stayed on screen with
/// no script), and the filing of old scripts under topics never makes a script the creator asked for wait.
@MainActor
@Suite("Generation deadlines")
struct GenerationDeadlinesTests {
    private let deadlines = GenerationDeadlines(firstResponse: .seconds(40), betweenResponses: .seconds(20), overall: .seconds(110))

    @Test func theFirstWordsHaveAWhileAndAfterThemSilenceIsShorter() {
        #expect(!deadlines.isStalled(elapsed: .seconds(39), sinceProgress: .seconds(39), hasResponded: false))
        #expect(deadlines.isStalled(elapsed: .seconds(40), sinceProgress: .seconds(40), hasResponded: false))
        #expect(!deadlines.isStalled(elapsed: .seconds(60), sinceProgress: .seconds(19), hasResponded: true))
        #expect(deadlines.isStalled(elapsed: .seconds(60), sinceProgress: .seconds(20), hasResponded: true))
    }

    @Test func aRequestThatKeepsAnsweringStillEndsAtTheOverallLimit() {
        #expect(!deadlines.isStalled(elapsed: .seconds(109), sinceProgress: .seconds(1), hasResponded: true))
        #expect(deadlines.isStalled(elapsed: .seconds(110), sinceProgress: .seconds(1), hasResponded: true))
    }

    @Test func theLimitsAreWhatKeepsAnOlderIPhoneFromWaitingForAMinuteOfNothing() {
        let standard = GenerationDeadlines.standard
        #expect(standard.firstResponse <= .seconds(45) && standard.betweenResponses <= .seconds(30) && standard.overall <= .seconds(120))
        #expect(standard.firstResponse >= .seconds(30), "a cold start of the model on an older iPhone needs room")
    }

    @Test func theProgressTrackerGivesUpOnSilenceAndForgivesWhatArrives() async throws {
        let quick = GenerationDeadlines(firstResponse: .milliseconds(400), betweenResponses: .milliseconds(400), overall: .seconds(30))
        let silent = GenerationProgress()
        #expect(!silent.checkStalled(against: quick))
        try await Task.sleep(for: .milliseconds(900))
        #expect(silent.checkStalled(against: quick) && silent.didStall)

        // Words arriving keep a request alive well past the time the first ones were allowed.
        let talking = GenerationProgress()
        for _ in 0..<4 {
            try await Task.sleep(for: .milliseconds(150))
            talking.noteProgress()
        }
        #expect(!talking.checkStalled(against: quick) && !talking.didStall && talking.hasResponded)
    }

    @Test func aTimedOutRequestIsToldToTheCreatorInWordsTheyCanActOn() {
        let error = ScriptAIError.timedOut
        #expect(error.explainsItself)
        #expect(error.localizedDescription == "Apple Intelligence is taking too long. Try again in a moment.")
        #expect(ScriptDetailViewModel.failureMessage(for: error) == error.localizedDescription)
    }

    // MARK: - Topics wait

    private func tagging(busy: Bool, topic: String?) -> (TopicTaggingService, ScriptLibraryService, FakeScriptWriter, TestDefaults) {
        let defaults = TestDefaults()
        let words = Array(repeating: "words about running and breathing", count: 4).joined(separator: " ")
        let scripts = (0..<3).map { TestData.script(title: "S\($0)", text: words) }
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: scripts), now: { TestData.now })
        library.load()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile.niches = [.fitness, .food]
        let writer = FakeScriptWriter()
        writer.isBusyForeground = busy
        writer.topicToPick = topic
        let service = TopicTaggingService(
            library: library, profile: profile, personalization: PersonalizationService(defaults: defaults.defaults), writer: writer
        )
        return (service, library, writer, defaults)
    }

    @Test func whileAScriptIsBeingWrittenNothingIsFiledAndNothingIsMarkedAsHavingNoTopic() async {
        let (service, library, writer, defaults) = tagging(busy: true, topic: nil)
        defer { defaults.tearDown() }
        await service.tagUntagged()
        #expect(writer.topicsAsked == 0)
        #expect(library.scripts.allSatisfy { $0.topic == nil }, "left to be filed another time, not marked")
    }

    @Test func whenNothingIsWaitingTheScriptsAreFiled() async {
        let (service, library, writer, defaults) = tagging(busy: false, topic: "Fitness & wellness")
        defer { defaults.tearDown() }
        await service.tagUntagged()
        #expect(writer.topicsAsked == 3)
        #expect(library.scripts.allSatisfy { $0.topic == "niche.fitness" })
    }

    @Test func aModelThatFindsNoTopicMarksTheScriptSoItIsNotAskedAgain() async {
        let (service, library, _, defaults) = tagging(busy: false, topic: nil)
        defer { defaults.tearDown() }
        await service.tagUntagged()
        #expect(library.scripts.allSatisfy { $0.topic == "" })
    }
}
