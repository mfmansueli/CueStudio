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
    private typealias F = NotificationFixtures
    private let monday = NotificationFixtures.monday

    private func plan(_ candidates: [CampaignCandidate], _ change: (inout PlanningContext) -> Void = { _ in }) -> NotificationPlanner.Result {
        var context = F.context()
        change(&context)
        return NotificationPlanner.plan(candidates, context: context)
    }

    private func reason(_ result: NotificationPlanner.Result, _ candidate: CampaignCandidate) -> SuppressionReason? {
        result.suppressed.first { $0.candidate == candidate }?.reason
    }

    // MARK: - Frequency

    @Test func oneAutomaticNotificationInAny24Hours() {
        let result = plan([F.candidate(), F.candidate()])
        #expect(result.scheduled.map(\.fireDate) == [monday, monday + F.hours(24)])
    }

    @Test func twoAutomaticNotificationsInAnySevenDays() {
        let result = plan([F.candidate(), F.candidate(), F.candidate()])
        #expect(result.scheduled.map(\.fireDate) == [monday, monday + F.days(1), monday + F.days(7)])
    }

    @Test func whatWasAlreadySentCountsAgainstTheCaps() {
        let result = plan([F.candidate()]) { $0.sent = [F.sent(monday - F.hours(4))] }
        #expect(result.scheduled.first?.fireDate == monday + F.hours(20))
    }

    @Test func oneToolOrIdeaInAnySevenDays() {
        let first = F.candidate(.feature, feature: .cleanUp)
        let second = F.candidate(.feature, feature: .autoCaptions)
        let result = plan([first, second])
        #expect(result.scheduled.map(\.fireDate) == [monday, monday + F.days(7)])
    }

    @Test func aToolWaitsThirtyDaysAfterItWasLastShown() {
        let result = plan([F.candidate(.feature, feature: .cleanUp)]) {
            $0.exposures = [FeatureExposure(feature: .cleanUp, date: monday - F.days(10), kind: .inApp)]
        }
        #expect(result.scheduled.first?.fireDate == monday + F.days(20))
    }

    @Test func aToolIsShownAtMostTwiceIn90Days() {
        let result = plan([F.candidate(.feature, feature: .cleanUp)]) {
            $0.exposures = [
                FeatureExposure(feature: .cleanUp, date: monday - F.days(80), kind: .notification),
                FeatureExposure(feature: .cleanUp, date: monday - F.days(40), kind: .inApp),
            ]
        }
        #expect(result.scheduled.first?.fireDate == monday + F.days(10))
    }

    // MARK: - Times the creator chose

    @Test func quietHoursMoveANotificationToTheirEnd() {
        let late = monday + F.hours(8)
        let result = plan([F.candidate(earliest: late)]) { $0.now = late }
        #expect(result.scheduled.first?.fireDate == F.date(2026, 10, 13, 9))
    }

    @Test func nothingAutomaticWithin12HoursOfAReminderOrTheRoutine() {
        let result = plan([F.candidate()]) { $0.userTimes = [monday + F.hours(4)] }
        #expect(result.scheduled.first?.fireDate == F.date(2026, 10, 13, 9))
    }

    @Test func aToolNeverGoesOnTheDayOfAMyCueVoiceTip() {
        let tool = F.candidate(.feature, feature: .logbook)
        let project = F.candidate()
        let tool2 = plan([tool]) { $0.tipDays = [monday - F.hours(4)] }
        let project2 = plan([project]) { $0.tipDays = [monday - F.hours(4)] }
        #expect(tool2.scheduled.first?.fireDate == F.date(2026, 10, 13, 9))
        #expect(project2.scheduled.first?.fireDate == monday)
    }

    @Test func aPauseHoldsEverythingAutomaticUntilItEnds() {
        let result = plan([F.candidate()]) { $0.pausedUntil = monday + F.days(3) }
        #expect(result.scheduled.first?.fireDate == monday + F.days(3))
    }

    // MARK: - Choosing

    @Test func theReturnAfterABreakTakesThePlaceOfEverythingElse() {
        let returning = F.candidate(.returnAfterInactivity, project: "return.1", earliest: monday + F.days(7))
        let later = F.candidate(earliest: monday + F.days(8))
        let result = plan([returning, later]) { $0.returnStart = monday + F.days(7) }
        #expect(result.scheduled.map(\.candidate) == [returning])
        #expect(reason(result, later) == .replacedByReturn)
    }

    @Test func oneNotificationPerProject() {
        let first = F.candidate(.recordingToFinish, project: "script.1")
        let second = F.candidate(.incompleteSharing, project: "script.1")
        let result = plan([first, second])
        #expect(result.scheduled.map(\.candidate) == [second])
        #expect(reason(result, first) == .sameProject)
    }

    @Test func higherPriorityTakesTheEarlierSlot() {
        let ready = F.candidate(.readyToRecord, earliest: monday - F.hours(4))
        let sharing = F.candidate(.incompleteSharing)
        let result = plan([ready, sharing])
        #expect(result.scheduled.map(\.candidate) == [sharing, ready])
        #expect(result.scheduled.map(\.fireDate) == [monday, monday + F.days(1)])
    }

    @Test func theScheduleIsBounded() {
        let result = plan((0..<6).map { _ in F.candidate() })
        #expect(result.scheduled.count == NotificationPolicy.standard.automaticCapacity)
        #expect(result.suppressed.allSatisfy { $0.reason == .capacity })
    }

    @Test func whatCantFitInTheHorizonWaitsForTheNextPlan() {
        let far = F.candidate(earliest: monday + F.days(30))
        #expect(reason(plan([far]), far) == .beyondHorizon)
    }

    @Test func theSameInputsGiveTheSamePlan() {
        let candidates = [F.candidate(), F.candidate(.feature, feature: .covers), F.candidate(.savedIdea)]
        #expect(plan(candidates).scheduled == plan(candidates.reversed()).scheduled)
    }
}
