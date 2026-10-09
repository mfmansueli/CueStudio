//
//  NotificationStorageTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What is kept and what a notification carries: versioned, readable across builds, never content, and a damaged store starts over without
/// inventing history.
@MainActor
@Suite("Notification storage")
struct NotificationStorageTests {
    private let monday = NotificationFixtures.monday

    // MARK: - State

    @Test func aStateRoundTrips() throws {
        var state = NotificationState(startedAt: monday)
        state.consent["discovery"] = true
        state.reminders = [Reminder(subject: .script(UUID()), time: LocalDateTime(monday, calendar: NotificationFixtures.utc), createdAt: monday, title: "A")]
        state.routine = CreationRoutine(weekdays: [2], hour: 7, minute: 30)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(NotificationState.self, from: data) == state)
    }

    @Test func anOlderOrPartialStateOpensWithDefaults() throws {
        let data = Data(#"{"startedAt": 800000000, "consent": {"projects": false}}"#.utf8)
        let state = try JSONDecoder().decode(NotificationState.self, from: data)
        #expect(state.schema == NotificationState.currentSchema)
        #expect(!state.isOn(.projects))
        #expect(state.isOn(.reminders) && !state.isOn(.discovery) && !state.isOn(.whatsNew))
        #expect(state.quietHours == .standard && state.reminders.isEmpty && !state.showsTitles)
    }

    @Test func anEntryThisBuildCantReadIsDroppedNotTheWholeList() throws {
        let good = AutomaticRecord(
            requestID: "cue.auto.a", campaign: .readyToRecord, feature: nil, projectKey: "p", fireDate: monday, status: .sent
        )
        let goodJSON = String(bytes: try JSONEncoder().encode(good), encoding: .utf8) ?? ""
        let unknown = goodJSON.replacingOccurrences(of: "readyToRecord", with: "fromTheFuture")
        let data = Data(#"{"startedAt": 800000000, "automatic": [\#(goodJSON), \#(unknown)]}"#.utf8)
        let state = try JSONDecoder().decode(NotificationState.self, from: data)
        #expect(state.automatic == [good])
    }

    @Test func aDamagedStoreStartsOverWithoutHistory() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        defaults.defaults.set(Data("not json".utf8), forKey: DefaultsKey.notificationState)
        let (state, loaded) = NotificationStateStore(defaults: defaults.defaults).load(now: monday)
        #expect(loaded == .damaged)
        #expect(state.automatic.isEmpty && state.exposures.isEmpty && state.startedAt == monday)
    }

    @Test func aFirstRunIsFreshAndASavedOneIsRestored() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = NotificationStateStore(defaults: defaults.defaults)
        #expect(store.load(now: monday).loaded == .fresh)
        var state = NotificationState(startedAt: monday)
        state.showsTitles = true
        store.save(state)
        let again = store.load(now: monday + 100)
        #expect(again.loaded == .restored && again.state.showsTitles && again.state.startedAt == monday)
    }

    // MARK: - Payload

    @Test func aPayloadRoundTripsAndCarriesNoWords() {
        let id = UUID()
        let payload = NotificationPayload(campaign: .feature, feature: .cleanUp, destination: .takeEditor(id, tool: .cleanUp), projectKey: "p")
        let text = payload.encoded()
        #expect(NotificationPayload.decode(text) == payload)
        #expect(payload.campaignName == "discover.cleanUp")
        #expect(!text.contains("title") && !text.contains("text"))
    }

    @Test func aPayloadAlwaysEncodesTheSameSoAnUnchangedRequestIsRecognised() {
        let payload = NotificationPayload(campaign: .reminder, destination: .shareQueue(takeID: UUID(), network: .reels), projectKey: "p", reminderID: UUID())
        #expect(Set((0..<20).map { _ in payload.encoded() }).count == 1)
    }

    @Test func aPayloadFromANewerBuildOrDamagedIsRefused() {
        var newer = NotificationPayload(campaign: .routine, destination: .nextAction)
        newer.version = NotificationPayload.currentVersion + 1
        #expect(NotificationPayload.decode(newer.encoded()) == nil)
        #expect(NotificationPayload.decode("{not json") == nil)
        #expect(NotificationPayload.decode(nil) == nil)
    }

    // MARK: - What's new

    @Test func whatsNewIsOnlyForAnUpdateAndOnlyOnce() {
        let entry = WhatsNewCatalog.Entry(version: "1.1", id: "reminders", destination: .notificationSettings)
        #expect(WhatsNewCatalog.announcements(current: "1.1", previous: nil, announced: [], catalog: [entry]).isEmpty)
        #expect(WhatsNewCatalog.announcements(current: "1.1", previous: "1.0", announced: [], catalog: [entry]) == [entry])
        #expect(WhatsNewCatalog.announcements(current: "1.1", previous: "1.0", announced: ["reminders"], catalog: [entry]).isEmpty)
        #expect(WhatsNewCatalog.announcements(current: "1.2", previous: "1.1", announced: [], catalog: [entry]).isEmpty)
        #expect(WhatsNewCatalog.all.isEmpty, "1.0 announces nothing: there is no earlier version to update from")
    }

    // MARK: - Router

    @Test func aTapIsQueuedOnceAndTakenInOrder() {
        let router = NotificationRouter()
        let first = NotificationInteraction(requestID: "cue.a", payloadText: nil, deliveredAt: monday)
        let second = NotificationInteraction(requestID: "cue.b", payloadText: nil, deliveredAt: monday)
        router.receive(first)
        router.receive(first)
        router.receive(second)
        #expect(router.take() == first)
        #expect(router.take() == second)
        #expect(router.take() == nil)
    }
}
