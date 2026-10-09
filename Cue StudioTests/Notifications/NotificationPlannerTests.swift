//
//  NotificationPlannerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The caps, quiet hours, exclusion windows and priorities that decide when an automatic notification may go (NOTIFICATIONS.md §6).
/// Every moment is on a UTC clock starting Monday 12 October 2026, 14:00.
@Suite("NotificationPlanner")
struct NotificationPlannerTests {
    private typealias Fixtures = NotificationFixtures
    private let monday = NotificationFixtures.monday

    private func plan(_ candidates: [CampaignCandidate], _ change: (inout PlanningContext) -> Void = { _ in }) -> NotificationPlanner.Result {
        var context = Fixtures.context()
        change(&context)
        return NotificationPlanner.plan(candidates, context: context)
    }

    private func reason(_ result: NotificationPlanner.Result, _ candidate: CampaignCandidate) -> SuppressionReason? {
        result.suppressed.first { $0.candidate == candidate }?.reason
    }

    // MARK: - Frequency

    @Test func oneAutomaticNotificationInAny24Hours() {
        let result = plan([Fixtures.candidate(), Fixtures.candidate()])
        #expect(result.scheduled.map(\.fireDate) == [monday, monday + Fixtures.hours(24)])
    }

    @Test func twoAutomaticNotificationsInAnySevenDays() {
        let result = plan([Fixtures.candidate(), Fixtures.candidate(), Fixtures.candidate()])
        #expect(result.scheduled.map(\.fireDate) == [monday, monday + Fixtures.days(1), monday + Fixtures.days(7)])
    }

    @Test func whatWasAlreadySentCountsAgainstTheCaps() {
        let result = plan([Fixtures.candidate()]) { $0.sent = [Fixtures.sent(monday - Fixtures.hours(4))] }
        #expect(result.scheduled.first?.fireDate == monday + Fixtures.hours(20))
    }

    @Test func oneToolOrIdeaInAnySevenDays() {
        let first = Fixtures.candidate(.feature, feature: .cleanUp)
        let second = Fixtures.candidate(.feature, feature: .autoCaptions)
        let result = plan([first, second])
        #expect(result.scheduled.map(\.fireDate) == [monday, monday + Fixtures.days(7)])
    }

    @Test func aToolWaitsThirtyDaysAfterItWasLastShown() {
        let result = plan([Fixtures.candidate(.feature, feature: .cleanUp)]) {
            $0.exposures = [FeatureExposure(feature: .cleanUp, date: monday - Fixtures.days(10), kind: .inApp)]
        }
        #expect(result.scheduled.first?.fireDate == monday + Fixtures.days(20))
    }

    @Test func aToolIsShownAtMostTwiceIn90Days() {
        let result = plan([Fixtures.candidate(.feature, feature: .cleanUp)]) {
            $0.exposures = [
                FeatureExposure(feature: .cleanUp, date: monday - Fixtures.days(80), kind: .notification),
                FeatureExposure(feature: .cleanUp, date: monday - Fixtures.days(40), kind: .inApp),
            ]
        }
        #expect(result.scheduled.first?.fireDate == monday + Fixtures.days(10))
    }

    // MARK: - Times the creator chose

    @Test func quietHoursMoveANotificationToTheirEnd() {
        let late = monday + Fixtures.hours(8)
        let result = plan([Fixtures.candidate(earliest: late)]) { $0.now = late }
        #expect(result.scheduled.first?.fireDate == Fixtures.date(2026, 10, 13, 9))
    }

    @Test func nothingAutomaticWithin12HoursOfAReminderOrTheRoutine() {
        let result = plan([Fixtures.candidate()]) { $0.userTimes = [monday + Fixtures.hours(4)] }
        #expect(result.scheduled.first?.fireDate == Fixtures.date(2026, 10, 13, 9))
    }

    @Test func aToolNeverGoesOnTheDayOfAMyCueVoiceTip() {
        let tool = Fixtures.candidate(.feature, feature: .logbook)
        let project = Fixtures.candidate()
        let tool2 = plan([tool]) { $0.tipDays = [monday - Fixtures.hours(4)] }
        let project2 = plan([project]) { $0.tipDays = [monday - Fixtures.hours(4)] }
        #expect(tool2.scheduled.first?.fireDate == Fixtures.date(2026, 10, 13, 9))
        #expect(project2.scheduled.first?.fireDate == monday)
    }

    @Test func aPauseHoldsEverythingAutomaticUntilItEnds() {
        let result = plan([Fixtures.candidate()]) { $0.pausedUntil = monday + Fixtures.days(3) }
        #expect(result.scheduled.first?.fireDate == monday + Fixtures.days(3))
    }

    // MARK: - Choosing

    @Test func theReturnAfterABreakTakesThePlaceOfEverythingElse() {
        let returning = Fixtures.candidate(.returnAfterInactivity, project: "return.1", earliest: monday + Fixtures.days(7))
        let later = Fixtures.candidate(earliest: monday + Fixtures.days(8))
        let result = plan([returning, later]) { $0.returnStart = monday + Fixtures.days(7) }
        #expect(result.scheduled.map(\.candidate) == [returning])
        #expect(reason(result, later) == .replacedByReturn)
    }

    @Test func oneNotificationPerProject() {
        let first = Fixtures.candidate(.recordingToFinish, project: "script.1")
        let second = Fixtures.candidate(.incompleteSharing, project: "script.1")
        let result = plan([first, second])
        #expect(result.scheduled.map(\.candidate) == [second])
        #expect(reason(result, first) == .sameProject)
    }

    @Test func higherPriorityTakesTheEarlierSlot() {
        let ready = Fixtures.candidate(.readyToRecord, earliest: monday - Fixtures.hours(4))
        let sharing = Fixtures.candidate(.incompleteSharing)
        let result = plan([ready, sharing])
        #expect(result.scheduled.map(\.candidate) == [sharing, ready])
        #expect(result.scheduled.map(\.fireDate) == [monday, monday + Fixtures.days(1)])
    }

    @Test func amongEqualToolsTheChosenOrderWins() {
        var second = Fixtures.candidate(.feature, feature: .covers)
        second.rank = 1
        var first = Fixtures.candidate(.feature, feature: .studioVoice)
        first.rank = 0
        let result = plan([second, first])
        #expect(result.scheduled.map(\.candidate) == [first, second])
        #expect(result.scheduled.map(\.fireDate) == [monday, monday + Fixtures.days(7)])
    }

    @Test func theScheduleIsBounded() {
        let result = plan((0..<6).map { _ in Fixtures.candidate() })
        #expect(result.scheduled.count == NotificationPolicy.standard.automaticCapacity)
        #expect(result.suppressed.allSatisfy { $0.reason == .capacity })
    }

    @Test func whatCantFitInTheHorizonWaitsForTheNextPlan() {
        let far = Fixtures.candidate(earliest: monday + Fixtures.days(30))
        #expect(reason(plan([far]), far) == .beyondHorizon)
    }

    @Test func theSameInputsGiveTheSamePlan() {
        let candidates = [Fixtures.candidate(), Fixtures.candidate(.feature, feature: .covers), Fixtures.candidate(.savedIdea)]
        #expect(plan(candidates).scheduled == plan(candidates.reversed()).scheduled)
    }
}
