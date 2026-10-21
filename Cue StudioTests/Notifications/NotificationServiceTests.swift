//
//  NotificationServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Consent, permission, reminders and what gets scheduled, on a fake center: nothing asks iOS at launch, "set" only when the system took it,
/// tools only with the creator's yes, and every change replaces or cancels by its identifier.
@MainActor
@Suite("NotificationService")
struct NotificationServiceTests {
    private typealias Fixtures = NotificationFixtures

    // MARK: - Permission and consent

    @Test func planningNeverAsksIOSForPermission() async {
        let harness = NotificationServiceHarness(status: .notDetermined)
        harness.addReadyScript()
        await harness.service.reconcile()
        #expect(harness.center.requestCount == 0)
        #expect(harness.center.requests.isEmpty)
    }

    @Test func toolsAndNewsStartOffAndTheRestOn() {
        let service = NotificationServiceHarness().service
        #expect(service.isOn(.reminders) && service.isOn(.projects) && service.isOn(.routine))
        #expect(!service.isOn(.discovery) && !service.isOn(.whatsNew))
    }

    @Test func turnOnAsksOnceAndADeniedIsNeverAskedAgain() async {
        let harness = NotificationServiceHarness(status: .notDetermined)
        harness.center.allowsWhenAsked = false
        #expect(await harness.service.allowEverything() == .denied)
        #expect(await harness.service.allowEverything() == .denied)
        #expect(harness.center.requestCount == 1)
        #expect(!harness.service.isOn(.discovery), "A no from iOS turns nothing on")
    }

    // MARK: - Reminders

    @Test func aReminderAsksTheFirstTimeAndIsSetOnlyWhenTheSystemTookIt() async {
        let harness = NotificationServiceHarness(status: .notDetermined)
        let script = harness.addReadyScript()
        let result = await harness.service.setReminder(.script(script), title: "Morning habits", at: harness.tomorrowAtTen())
        #expect(result == .scheduled(Fixtures.date(2026, 10, 13, 10)))
        #expect(harness.center.requestCount == 1)
        let reminder = harness.service.state.reminders.first
        #expect(reminder?.isScheduled == true)
        let request = reminder.flatMap { harness.center.requests[$0.requestID] }
        #expect(request?.trigger == .at(harness.tomorrowAtTen()))
        #expect(request?.payload.destination == .script(script))
        #expect(request?.content.title == "Your script is waiting", "No title in previews unless the creator allowed it")
    }

    @Test func withNotificationsOffAReminderIsKeptInCueAndNotCalledSet() async {
        let harness = NotificationServiceHarness(status: .denied)
        let script = harness.addReadyScript()
        let result = await harness.service.setReminder(.script(script), title: "A", at: harness.tomorrowAtTen())
        #expect(result == .savedNotificationsOff)
        #expect(harness.center.requests.isEmpty && harness.center.requestCount == 0)
        #expect(harness.service.state.reminders.map(\.isScheduled) == [false])
    }

    @Test func aReminderTheSystemRefusesIsNotKept() async {
        let harness = NotificationServiceHarness()
        harness.center.failsToAdd = true
        let script = harness.addReadyScript()
        #expect(await harness.service.setReminder(.script(script), title: "A", at: harness.tomorrowAtTen()) == .failed)
        #expect(harness.service.state.reminders.isEmpty)
        #expect(harness.service.state.counters["reminders.reminder.scheduling_failed"] == 1)
    }

    @Test func aReminderInThePastIsRefused() async {
        let harness = NotificationServiceHarness()
        let past = LocalDateTime(year: 2026, month: 10, day: 12, hour: 9, minute: 0)
        #expect(await harness.service.setReminder(.script(UUID()), title: "A", at: past) == .past)
    }

    @Test func editingAReminderReplacesItAndCancellingTakesItBack() async {
        let harness = NotificationServiceHarness()
        let script = harness.addReadyScript()
        _ = await harness.service.setReminder(.script(script), title: "A", at: harness.tomorrowAtTen())
        let id = harness.service.state.reminders[0].id
        let later = LocalDateTime(year: 2026, month: 10, day: 14, hour: 18, minute: 0)
        _ = await harness.service.setReminder(.script(script), title: "A", at: later, replacing: id)
        #expect(harness.service.state.reminders.count == 1 && harness.center.requests.count == 1)
        #expect(harness.center.requests[NotificationIdentifier.reminder(id)]?.trigger == .at(later))
        harness.service.cancelReminder(id)
        #expect(harness.service.state.reminders.isEmpty && harness.center.requests.isEmpty)
    }

    @Test func remindersBeyondThePlacesWaitInCue() async {
        var policy = NotificationPolicy.standard
        policy.maxPending = policy.routineCapacity + policy.automaticCapacity + 1
        let harness = NotificationServiceHarness(policy: policy)
        let script = harness.addReadyScript()
        #expect(await harness.service.setReminder(.script(script), title: "A", at: harness.tomorrowAtTen()) == .scheduled(Fixtures.date(2026, 10, 13, 10)))
        let later = LocalDateTime(year: 2026, month: 10, day: 20, hour: 10, minute: 0)
        #expect(await harness.service.setReminder(.script(script), title: "A", at: later) == .savedWaiting)
    }

    @Test func aReminderWhoseScriptIsGoneIsCancelled() async {
        let harness = NotificationServiceHarness()
        let script = harness.addReadyScript()
        _ = await harness.service.setReminder(.script(script), title: "A", at: harness.tomorrowAtTen())
        harness.facts.facts.scripts = []
        await harness.service.reconcile()
        #expect(harness.service.state.reminders.isEmpty)
        #expect(harness.center.requests.values.allSatisfy { !NotificationIdentifier.isReminder($0.identifier) })
    }

    @Test func aPostLaterReminderGoesOnceThatNetworkIsPosted() async {
        let take = UUID()
        var facts = NotificationFacts(now: Fixtures.monday)
        facts.takes = [Fixtures.take(id: take, scriptID: nil)]
        facts.queues = [NotificationFacts.QueueFact(takeID: take, title: "A", waiting: [.reels], updatedAt: Fixtures.monday)]
        let harness = NotificationServiceHarness(facts: facts)
        _ = await harness.service.setReminder(.share(takeID: take, network: .reels), title: "A", at: harness.tomorrowAtTen())
        await harness.service.reconcile()
        #expect(harness.service.state.reminders.count == 1)
        harness.facts.facts.queues = []
        await harness.service.reconcile()
        #expect(harness.service.state.reminders.isEmpty)
    }

    @Test func aTimeInTheQuietHoursIsSaid() {
        let service = NotificationServiceHarness().service
        #expect(service.isInQuietHours(LocalDateTime(year: 2026, month: 10, day: 13, hour: 22, minute: 30)))
        #expect(!service.isInQuietHours(LocalDateTime(year: 2026, month: 10, day: 13, hour: 18, minute: 0)))
    }

    // MARK: - Automatic

    @Test func aProjectIsPlannedAndARoutineRingsWeekly() async {
        let harness = NotificationServiceHarness()
        harness.addReadyScript()
        await harness.service.reconcile()
        let first = harness.automatic().first { $0.payload.campaign == .firstRecording }
        #expect(first?.trigger == .at(LocalDateTime(Fixtures.monday + Fixtures.hours(48), calendar: Fixtures.utc)))
        #expect(first?.isPassive == false)
        await harness.service.setRoutine(CreationRoutine(weekdays: [2, 6], hour: 18, minute: 0))
        let routine = harness.center.requests(of: .routine)
        #expect(routine.count == 2 && routine.allSatisfy { $0.payload.destination == .nextAction })
    }

    @Test func toolsAreOnlyScheduledWithTheCreatorsYes() async {
        // Two drafts too short to nudge about: only the tool can be planned.
        var facts = NotificationFacts(now: Fixtures.monday)
        facts.scripts = [Fixtures.script(.draft, words: 3), Fixtures.script(.draft, words: 3)]
        facts.capabilities.aiWriting = true
        let harness = NotificationServiceHarness(facts: facts)
        await harness.service.reconcile()
        #expect(harness.center.requests(of: .feature).isEmpty)
        await harness.service.setGroup(.news, isOn: true)
        let tool = harness.center.requests(of: .feature).first
        #expect(tool?.payload.feature == .myCueVoice && tool?.isPassive == true)
    }

    @Test func turningACategoryOffCancelsWhatItHadWaiting() async {
        let harness = NotificationServiceHarness()
        harness.addReadyScript()
        await harness.service.reconcile()
        #expect(!harness.automatic().isEmpty)
        await harness.service.setGroup(.finish, isOn: false)
        #expect(harness.automatic().isEmpty)
        #expect(harness.service.state.counters["category.projects.opted_out"] == 1)
    }

    // MARK: - The three switches and Turn on

    /// Every kind of notification but the creator's own reminders falls under exactly one switch; those always arrive.
    @Test func theSwitchesHoldEveryCategoryOnceAndRemindersAlwaysArrive() async {
        let held = NotificationGroup.allCases.flatMap(\.categories)
        #expect(held.count == NotificationCategory.allCases.count - 1)
        #expect(Set(held) == Set(NotificationCategory.allCases).subtracting([.reminders]))
        let harness = NotificationServiceHarness()
        for group in NotificationGroup.allCases { await harness.service.setGroup(group, isOn: false) }
        #expect(harness.service.isOn(.reminders))
    }

    @Test func aSwitchSetsAllItsCategories() async {
        let harness = NotificationServiceHarness()
        await harness.service.setGroup(.finish, isOn: false)
        #expect(!harness.service.isOn(.projects) && !harness.service.isGroupOn(.finish))
        await harness.service.setGroup(.news, isOn: true)
        #expect(harness.service.isOn(.discovery) && harness.service.isOn(.whatsNew))
    }

    @Test func theRoutineSwitchedOnStartsOnItsUsualDays() async {
        let harness = NotificationServiceHarness()
        await harness.service.setGroup(.routine, isOn: true)
        #expect(harness.service.state.routine == CreationRoutine())
    }

    /// The card names everything Turn on allows, so iOS's yes turns on tools and news too, and the routine on its usual days.
    @Test func turnOnWithAYesTurnsEverythingOn() async {
        let harness = NotificationServiceHarness(status: .notDetermined)
        #expect(await harness.service.allowEverything().canSchedule)
        #expect(NotificationCategory.allCases.allSatisfy { harness.service.isOn($0) })
        #expect(harness.service.state.routine != nil)
    }

    @Test func turnOnWithANoChangesNothing() async {
        let harness = NotificationServiceHarness(status: .notDetermined)
        harness.center.allowsWhenAsked = false
        #expect(await harness.service.allowEverything() == .denied)
        #expect(!harness.service.isOn(.discovery) && !harness.service.isOn(.whatsNew))
        #expect(harness.service.state.routine == nil)
    }

    @Test func anUnchangedPlanIsNotHandedToTheSystemAgainButANewLanguageIs() async {
        let harness = NotificationServiceHarness()
        harness.addReadyScript()
        await harness.service.reconcile()
        let added = harness.center.addCount
        await harness.service.reconcile()
        #expect(harness.center.addCount == added)
        harness.service.interfaceLanguage = { "pt-BR" }
        await harness.service.reconcile()
        #expect(harness.center.addCount > added)
    }

    @Test func aFinishedExportIsNotifiedOnlyWhenCueIsNotOnScreen() async {
        let harness = NotificationServiceHarness()
        let take = UUID()
        await harness.service.exportFinished(takeID: take, savedToPhotos: true)
        #expect(harness.center.requests.isEmpty)
        harness.service.isAppActive = false
        await harness.service.exportFinished(takeID: take, savedToPhotos: true)
        let request = harness.center.requests[NotificationIdentifier.exportReady(takeID: take)]
        #expect(request?.trigger == .after(1) && request?.payload.destination == .takeReview(take))
    }

    @Test func erasingTakesEverythingBackButKeepsTheChoices() async {
        let harness = NotificationServiceHarness()
        let script = harness.addReadyScript()
        await harness.service.setGroup(.news, isOn: true)
        _ = await harness.service.setReminder(.script(script), title: "A", at: harness.tomorrowAtTen())
        await harness.service.eraseAll()
        #expect(harness.center.requests.isEmpty)
        #expect(harness.service.state.reminders.isEmpty && harness.service.state.counters.isEmpty)
        #expect(harness.service.isOn(.discovery))
    }
}
