//
//  NotificationInviteTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Cue's invitation before the system's question: only while iOS hasn't been asked, first after a recording, once more 14 days after a
/// "Not now" on a finished script, twice at most, never while the creator is busy or on a day something else was introduced; "Allow" is
/// what asks iOS, and each answer is counted.
@MainActor
@Suite("Notification invite")
struct NotificationInviteTests {
    private let day: TimeInterval = 24 * 3600

    @Test func theFirstInviteWaitsForARecording() async {
        let harness = NotificationServiceHarness(status: .notDetermined)
        #expect(await harness.service.invite(.firstRecording, hasRecorded: false) == nil)
        #expect(await harness.service.invite(.firstRecording, hasRecorded: true) == .firstRecording)
        #expect(await harness.service.invite(.readyScript, hasRecorded: true) == nil, "A finished script is the second chance, never the first")
        #expect(harness.center.requestCount == 0, "Inviting never asks iOS")
    }

    @Test(arguments: [NotificationAuthorization.authorized, .denied, .provisional])
    func onceIOSWasAskedThereIsNoInvite(_ status: NotificationAuthorization) async {
        let harness = NotificationServiceHarness(status: status)
        #expect(await harness.service.invite(.firstRecording, hasRecorded: true) == nil)
    }

    @Test func theSecondChanceIsAFinishedScriptFourteenDaysAfterNotNow() async {
        let harness = NotificationServiceHarness(status: .notDetermined)
        let service = harness.service
        service.inviteShown(.firstRecording)
        service.inviteDeclined(.firstRecording)
        service.introsThisSession = 0
        harness.now = harness.now.addingTimeInterval(13 * day)
        #expect(await service.invite(.readyScript, hasRecorded: true) == nil, "13 days are too soon")
        harness.now = harness.now.addingTimeInterval(day)
        #expect(await service.invite(.firstRecording, hasRecorded: true) == nil, "The recording invite is spent")
        #expect(await service.invite(.readyScript, hasRecorded: false) == .readyScript)
    }

    @Test func twoInvitesInTheAppsLifeAtMost() async {
        let harness = NotificationServiceHarness(status: .notDetermined)
        let service = harness.service
        service.inviteShown(.firstRecording)
        harness.now = harness.now.addingTimeInterval(15 * day)
        service.introsThisSession = 0
        service.inviteShown(.readyScript)
        harness.now = harness.now.addingTimeInterval(60 * day)
        service.introsThisSession = 0
        #expect(await service.invite(.readyScript, hasRecorded: true) == nil)
        #expect(await service.invite(.firstRecording, hasRecorded: true) == nil)
    }

    @Test func noInviteWhileBusyOffOrAfterAnotherIntroduction() async {
        let busy = NotificationServiceHarness(status: .notDetermined)
        busy.service.isForegroundBusy = { true }
        #expect(await busy.service.invite(.firstRecording, hasRecorded: true) == nil)

        let off = NotificationServiceHarness(status: .notDetermined)
        off.service.invitesEnabled = false
        #expect(await off.service.invite(.firstRecording, hasRecorded: true) == nil)

        let session = NotificationServiceHarness(status: .notDetermined)
        session.service.introsThisSession = 1
        #expect(await session.service.invite(.firstRecording, hasRecorded: true) == nil, "One introduction a session")

        let tipDay = NotificationServiceHarness(status: .notDetermined)
        tipDay.service.tipDays = { [tipDay.now] }
        #expect(await tipDay.service.invite(.firstRecording, hasRecorded: true) == nil, "Not on a My Cue Voice tip's day")

        let toolDay = NotificationServiceHarness(status: .notDetermined)
        toolDay.service.mutate { $0.exposures.append(FeatureExposure(feature: .cleanUp, date: toolDay.now, kind: .inApp)) }
        #expect(await toolDay.service.invite(.firstRecording, hasRecorded: true) == nil, "Not on a day a tool was introduced")
    }

    @Test func allowAsksIOSOnceAndCountsTheAnswer() async {
        let harness = NotificationServiceHarness(status: .notDetermined)
        let service = harness.service
        service.inviteShown(.firstRecording)
        #expect(await service.inviteAccepted(.firstRecording) == .authorized)
        #expect(harness.center.requestCount == 1)
        #expect(service.count(.eligible, campaign: "invite.firstRecording") == 1)
        #expect(service.count(.featureStarted, campaign: "invite.firstRecording") == 1)
        #expect(service.count(.featureCompleted, campaign: "invite.firstRecording") == 1)
    }

    @Test func aNoFromIOSIsCountedAsStartedNotCompleted() async {
        let harness = NotificationServiceHarness(status: .notDetermined)
        harness.center.allowsWhenAsked = false
        #expect(await harness.service.inviteAccepted(.readyScript) == .denied)
        #expect(harness.service.count(.featureStarted, campaign: "invite.readyScript") == 1)
        #expect(harness.service.count(.featureCompleted, campaign: "invite.readyScript") == 0)
    }

    @Test func notNowIsCountedAndDoesNotAskIOS() {
        let harness = NotificationServiceHarness(status: .notDetermined)
        harness.service.inviteShown(.firstRecording)
        harness.service.inviteDeclined(.firstRecording)
        #expect(harness.service.count(.snoozed, campaign: "invite.firstRecording") == 1)
        #expect(harness.center.requestCount == 0)
        #expect(harness.service.introsThisSession == 1, "Nothing else is introduced in this session")
    }

    @Test func invitesShownSurviveDeleteMyCueData() async {
        let harness = NotificationServiceHarness(status: .notDetermined)
        harness.service.inviteShown(.firstRecording)
        await harness.service.eraseAll()
        #expect(harness.service.state.invitesShown.count == 1, "Erasing data doesn't bring the invitation back")
    }

    @Test func invitesShownAreReadBackFromAnOlderState() throws {
        var state = NotificationState(startedAt: NotificationFixtures.monday)
        state.invitesShown = [NotificationFixtures.monday]
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(NotificationState.self, from: data)
        #expect(decoded.invitesShown == [NotificationFixtures.monday])

        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "invitesShown")
        let older = try JSONDecoder().decode(NotificationState.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(older.invitesShown.isEmpty, "A state saved before invitations decodes without them")
    }
}
