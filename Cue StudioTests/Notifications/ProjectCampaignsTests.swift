//
//  ProjectCampaignsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// One next step per project, read from its real state, waiting from its own last change and never from before the notifications started.
@Suite("ProjectCampaigns")
struct ProjectCampaignsTests {
    private typealias Fixtures = NotificationFixtures
    private let monday = NotificationFixtures.monday
    private let policy = NotificationPolicy.standard
    /// Long before the projects: their own dates decide.
    private let longAgo = NotificationFixtures.monday - NotificationFixtures.days(365)

    private func candidates(_ facts: NotificationFacts, startedAt: Date? = nil) -> [CampaignCandidate] {
        ProjectCampaigns.candidates(facts: facts, startedAt: startedAt ?? longAgo, policy: policy)
    }

    @Test func aFirstFinishedScriptWithNothingRecordedAsksForTheFirstRecording() {
        let script = Fixtures.script(.ready)
        var facts = NotificationFacts(now: monday)
        facts.scripts = [script]
        let found = candidates(facts)
        #expect(found.map(\.campaign) == [.firstRecording])
        #expect(found.first?.earliest == monday + Fixtures.hours(48))
        #expect(found.first?.destination == .script(script.id))
    }

    @Test func onceSomethingIsRecordedAFinishedScriptIsReadyToRecord() {
        let recorded = Fixtures.script(.recorded)
        let ready = Fixtures.script(.ready)
        var facts = NotificationFacts(now: monday)
        facts.scripts = [recorded, ready]
        facts.takes = [Fixtures.take(scriptID: recorded.id, exported: true, tools: [])]
        facts.takes[0].stage = .shared
        #expect(candidates(facts).map(\.campaign) == [.readyToRecord])
    }

    @Test func aDraftNeedsRealWordsAndWaitsThreeDays() {
        var facts = NotificationFacts(now: monday)
        facts.scripts = [Fixtures.script(.draft, words: 3)]
        #expect(candidates(facts).isEmpty)
        let draft = Fixtures.script(.draft, words: 40)
        facts.scripts = [draft]
        let found = candidates(facts)
        #expect(found.map(\.campaign) == [.unfinishedScript])
        #expect(found.first?.earliest == monday + Fixtures.hours(72))
        #expect(found.first?.destination == .scriptEditor(draft.id))
    }

    @Test func aRecordingWithWorkLeftOpensWhereTheWorkIs() {
        let script = Fixtures.script(.recorded)
        let take = Fixtures.take(scriptID: script.id, stage: .edit)
        var facts = NotificationFacts(now: monday)
        facts.scripts = [script]
        facts.takes = [take]
        let found = candidates(facts)
        #expect(found.map(\.campaign) == [.recordingToFinish])
        #expect(found.first?.destination == .takeEditor(take.id, tool: nil))
        #expect(found.first?.earliest == monday + Fixtures.hours(48))
    }

    @Test func anExportedVideoHasNoNextStep() {
        let script = Fixtures.script(.recorded)
        var facts = NotificationFacts(now: monday)
        facts.scripts = [script]
        facts.takes = [Fixtures.take(scriptID: script.id, stage: .shared, exported: true)]
        #expect(candidates(facts).isEmpty)
    }

    @Test func aQueueWithNetworksWaitingIsTheProjectsOneStep() {
        let script = Fixtures.script(.recorded)
        let take = Fixtures.take(scriptID: script.id, stage: .shared, exported: true)
        var facts = NotificationFacts(now: monday)
        facts.scripts = [script]
        facts.takes = [take]
        facts.queues = [NotificationFacts.QueueFact(takeID: take.id, title: "Morning habits", waiting: [.reels], updatedAt: monday)]
        let found = candidates(facts)
        #expect(found.map(\.campaign) == [.incompleteSharing])
        #expect(found.first?.destination == .shareQueue(takeID: take.id, network: nil))
        #expect(found.first?.earliest == monday + Fixtures.hours(24))
    }

    @Test func oldProjectsWaitFromWhenTheNotificationsStarted() {
        var facts = NotificationFacts(now: monday)
        facts.scripts = [Fixtures.script(.ready, updatedAt: monday - Fixtures.days(30))]
        let found = candidates(facts, startedAt: monday)
        #expect(found.first?.earliest == monday + Fixtures.hours(48))
    }

    @Test func theOldestWaitingNoteComesUpAfterAWeek() {
        let old = NotificationFacts.NoteFact(id: UUID(), createdAt: monday - Fixtures.days(10))
        let newer = NotificationFacts.NoteFact(id: UUID(), createdAt: monday - Fixtures.days(2))
        var facts = NotificationFacts(now: monday)
        facts.notes = [newer, old]
        let found = candidates(facts)
        #expect(found.map(\.campaign) == [.savedIdea])
        #expect(found.first?.destination == .logbook(entryID: old.id))
        #expect(found.first?.earliest == old.createdAt + Fixtures.days(7))
    }

    @Test func aFreestyleTakeIsItsOwnProject() {
        let take = Fixtures.take(scriptID: nil, stage: .ready)
        var facts = NotificationFacts(now: monday)
        facts.takes = [take]
        #expect(candidates(facts).first?.projectKey == ProjectKey.take(take.id))
    }

    @Test func twoAttemptsAfterABreakAboutTheMostUsefulProject() {
        let draft = Fixtures.candidate(.unfinishedScript)
        let sharing = Fixtures.candidate(.incompleteSharing)
        let attempts = ProjectCampaigns.returnAttempts(after: monday, projects: [draft, sharing], policy: policy)
        #expect(attempts.map(\.earliest) == [monday + Fixtures.days(7), monday + Fixtures.days(21)])
        #expect(attempts.allSatisfy { $0.campaign == .returnAfterInactivity && $0.subject == sharing.subject })
        let nothing = ProjectCampaigns.returnAttempts(after: monday, projects: [], policy: policy)
        #expect(nothing.allSatisfy { $0.destination == .newScript && $0.subject == .entryPoint })
    }
}
