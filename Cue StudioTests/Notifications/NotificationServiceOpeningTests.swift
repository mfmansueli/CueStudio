//
//  NotificationServiceOpeningTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Opening a notification and the moments around it: each delivery once, a payload this build reads, a tool introduced before it opens,
/// what happens while the creator is busy, and what is credited to the campaign (and only for 24 hours).
@MainActor
@Suite("NotificationService opening")
struct NotificationServiceOpeningTests {
    private typealias Fixtures = NotificationFixtures

    @Test func aTapOpensItsDestinationOnceHoweverOftenTheSystemCallsBack() async {
        let harness = NotificationServiceHarness()
        let script = harness.addReadyScript()
        let tap = harness.tap(NotificationPayload(campaign: .readyToRecord, destination: .script(script), projectKey: ProjectKey.script(script)))
        #expect(await harness.service.open(tap)?.destination == .script(script))
        #expect(await harness.service.open(tap) == nil)
        #expect(harness.service.count(.opened, campaign: "projects.readyToRecord") == 1)
    }

    @Test func aPayloadThisBuildCantReadOpensNothing() async {
        let harness = NotificationServiceHarness()
        let damaged = NotificationInteraction(requestID: "cue.auto.x", payloadText: "{\"version\": 99}", deliveredAt: Fixtures.monday)
        let foreign = NotificationInteraction(
            requestID: "someone.else", payloadText: NotificationPayload(campaign: .routine, destination: .scripts).encoded(), deliveredAt: Fixtures.monday
        )
        #expect(await harness.service.open(damaged) == nil)
        #expect(await harness.service.open(foreign) == nil)
    }

    @Test func aToolsNotificationOpensItsIntroductionFirst() async {
        let harness = NotificationServiceHarness()
        let take = UUID()
        let payload = NotificationPayload(campaign: .feature, feature: .cleanUp, destination: .takeEditor(take, tool: .cleanUp), projectKey: "p")
        let opening = await harness.service.open(harness.tap(payload))
        #expect(opening?.intro?.feature == .cleanUp)
        #expect(opening?.intro?.destination == .takeEditor(take, tool: .cleanUp))
    }

    @Test func anOpenedReminderHasDoneItsJob() async {
        let harness = NotificationServiceHarness()
        let script = harness.addReadyScript()
        _ = await harness.service.setReminder(.script(script), title: "A", at: harness.tomorrowAtTen())
        let reminder = harness.service.state.reminders[0]
        let payload = NotificationPayload(campaign: .reminder, destination: .script(script), reminderID: reminder.id)
        _ = await harness.service.open(harness.tap(payload, request: reminder.requestID))
        #expect(harness.service.state.reminders.isEmpty)
    }

    // MARK: - Credit

    @Test func aToolUsedWithin24HoursOfItsNotificationIsCompleted() async {
        let harness = NotificationServiceHarness()
        let payload = NotificationPayload(campaign: .feature, feature: .cleanUp, destination: .scripts)
        _ = await harness.service.open(harness.tap(payload))
        harness.facts.facts.adopted = [.cleanUp]
        await harness.service.reconcile()
        #expect(harness.service.count(.featureCompleted, campaign: "discover.cleanUp") == 1)
    }

    @Test func openingIsNotUsingAndCreditExpiresAfter24Hours() async {
        let harness = NotificationServiceHarness()
        let payload = NotificationPayload(campaign: .feature, feature: .covers, destination: .scripts)
        _ = await harness.service.open(harness.tap(payload))
        await harness.service.reconcile()
        #expect(harness.service.count(.featureCompleted, campaign: "discover.covers") == 0)
        harness.now = Fixtures.monday + Fixtures.hours(25)
        harness.facts.facts.adopted = [.covers]
        await harness.service.reconcile()
        #expect(harness.service.count(.featureCompleted, campaign: "discover.covers") == 0)
        #expect(harness.service.state.adopted[FeatureID.covers.rawValue] != nil, "Used is still used: its introductions stop")
    }

    @Test func aProjectThatMovedOnCompletesItsNextAction() async {
        let harness = NotificationServiceHarness()
        let script = harness.addReadyScript()
        let payload = NotificationPayload(campaign: .firstRecording, destination: .script(script), projectKey: ProjectKey.script(script))
        _ = await harness.service.open(harness.tap(payload))
        harness.facts.facts.scripts[0].state = .recorded
        harness.facts.facts.takes = [Fixtures.take(scriptID: script)]
        await harness.service.reconcile()
        #expect(harness.service.count(.nextActionCompleted, campaign: "projects.firstRecording") == 1)
    }

    // MARK: - While Cue is on screen

    @Test func whileBusyNothingRingsAndAToolWaitsForAQuietMoment() {
        let harness = NotificationServiceHarness()
        let service = harness.service
        let project = NotificationPayload(campaign: .readyToRecord, destination: .scripts)
        let tool = NotificationPayload(campaign: .feature, feature: .covers, destination: .scripts)
        #expect(service.foregroundPresentation(for: project) == .banner)
        #expect(service.foregroundPresentation(for: tool) == .listOnly)
        service.isForegroundBusy = { true }
        #expect(service.foregroundPresentation(for: project) == .listOnly)
        #expect(service.foregroundPresentation(for: tool) == .hidden)
        #expect(service.state.deferredIntro == .covers)
    }

    @Test func aNotificationAboutSomethingGoneIsNotShown() {
        let service = NotificationServiceHarness().service
        service.isAlive = { _ in false }
        #expect(service.foregroundPresentation(for: NotificationPayload(campaign: .readyToRecord, destination: .script(UUID()))) == .hidden)
    }

    // MARK: - In the app

    @Test func anIntroductionInTheAppNeedsTheCreatorsYesAndComesOnceASession() async {
        var facts = NotificationFacts(now: Fixtures.monday)
        facts.takes = [Fixtures.take(scriptID: nil)]
        let harness = NotificationServiceHarness(facts: facts)
        #expect(await harness.service.inAppIntro(afterSession: true) == nil)
        await harness.service.setCategory(.discovery, isOn: true)
        let intro = await harness.service.inAppIntro(afterSession: true)
        #expect(intro != nil && intro?.source == .inApp)
        if let intro { harness.service.introShown(intro) }
        #expect(await harness.service.inAppIntro(afterSession: true) == nil)
        #expect(harness.service.introducedToday)
    }

    @Test func notNowWaitsAndDontSuggestIsForGood() async {
        let harness = NotificationServiceHarness()
        let request = FeatureIntroRequest(feature: .covers, destination: .scripts, projectKey: "p", source: .inApp)
        harness.service.introSnoozed(request)
        #expect(harness.service.state.snoozedFeatures[FeatureID.covers.rawValue] == Fixtures.monday + Fixtures.days(30))
        harness.service.introDeclined(request)
        #expect(harness.service.state.isNotInterested(in: .covers))
        #expect(harness.service.count(.optedOut, campaign: "inApp.covers") == 1)
    }

    @Test func tryItIsStartedNotCompleted() {
        let harness = NotificationServiceHarness()
        let request = FeatureIntroRequest(feature: .covers, destination: .scripts, projectKey: "p", source: .notification(campaign: "discover.covers"))
        harness.service.introAccepted(request)
        #expect(harness.service.count(.featureStarted, campaign: "discover.covers") == 1)
        #expect(harness.service.count(.featureCompleted, campaign: "discover.covers") == 0)
    }

    @Test func aUseOnlyAnEventCanTellIsRemembered() {
        let harness = NotificationServiceHarness()
        harness.service.recordUse(.remoteControl)
        harness.service.recordUse(.remoteControl)
        #expect(harness.service.usedFeatures == [.remoteControl])
    }
}
