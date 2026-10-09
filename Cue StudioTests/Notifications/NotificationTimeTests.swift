//
//  NotificationTimeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Clock times for reminders (`LocalDateTime`, `ReminderChoice`), quiet hours and the routine, across daylight saving and time zones.
@Suite("Notification times")
struct NotificationTimeTests {
    private typealias Fixtures = NotificationFixtures
    private let newYork = NotificationFixtures.calendar("America/New_York")

    // MARK: - LocalDateTime

    @Test func aTimeSkippedByDaylightSavingRingsJustAfterTheGap() {
        // 8 March 2026, New York: 2:00 jumps to 3:00.
        let skipped = LocalDateTime(year: 2026, month: 3, day: 8, hour: 2, minute: 30)
        let date = skipped.date(in: newYork)
        #expect(date.map { LocalDateTime($0, calendar: newYork) } == LocalDateTime(year: 2026, month: 3, day: 8, hour: 3, minute: 0))
        #expect(skipped.resolved(in: newYork)?.hour == 3)
    }

    @Test func aTimeThatHappensTwiceRingsTheFirstTime() {
        // 1 November 2026, New York: 1:00–2:00 happens twice.
        let twice = LocalDateTime(year: 2026, month: 11, day: 1, hour: 1, minute: 30)
        let first = Fixtures.date(2026, 11, 1, 5, 30) // 1:30 EDT is 5:30 UTC; the second 1:30 (EST) is 6:30 UTC.
        #expect(twice.date(in: newYork) == first)
    }

    @Test func aReminderKeepsItsClockTimeInANewTimeZone() {
        let ten = LocalDateTime(year: 2026, month: 10, day: 13, hour: 10, minute: 0)
        let tokyo = Fixtures.calendar("Asia/Tokyo")
        #expect(ten.date(in: tokyo).map { LocalDateTime($0, calendar: tokyo) } == ten)
        #expect(ten.date(in: tokyo) != ten.date(in: newYork))
    }

    @Test func clockTimesCompareInOrder() {
        let morning = LocalDateTime(year: 2026, month: 10, day: 13, hour: 9, minute: 0)
        let evening = LocalDateTime(year: 2026, month: 10, day: 13, hour: 20, minute: 0)
        #expect(morning < evening)
    }

    // MARK: - Choices

    @Test func tonightIsEightUntilHalfPastSeven() {
        let afternoon = Fixtures.date(2026, 10, 12, 15)
        #expect(ReminderChoice.tonight.time(now: afternoon, calendar: Fixtures.utc) == LocalDateTime(year: 2026, month: 10, day: 12, hour: 20, minute: 0))
        #expect(ReminderChoice.tonight.time(now: Fixtures.date(2026, 10, 12, 19, 45), calendar: Fixtures.utc) == nil)
    }

    @Test func tomorrowIsTenInTheMorning() {
        let late = Fixtures.date(2026, 10, 12, 23, 30)
        #expect(ReminderChoice.tomorrow.time(now: late, calendar: Fixtures.utc) == LocalDateTime(year: 2026, month: 10, day: 13, hour: 10, minute: 0))
    }

    @Test func aTimeInThePastIsRefused() {
        let now = Fixtures.date(2026, 10, 12, 15)
        #expect(ReminderChoice.isPast(LocalDateTime(year: 2026, month: 10, day: 12, hour: 14, minute: 0), now: now, calendar: Fixtures.utc))
        #expect(!ReminderChoice.isPast(LocalDateTime(year: 2026, month: 10, day: 12, hour: 16, minute: 0), now: now, calendar: Fixtures.utc))
    }

    // MARK: - Quiet hours

    @Test func quietHoursRunOverMidnight() {
        let quiet = QuietHours.standard
        #expect(quiet.contains(minuteOfDay: 22 * 60))
        #expect(quiet.contains(minuteOfDay: 3 * 60))
        #expect(!quiet.contains(minuteOfDay: 9 * 60))
        #expect(!quiet.contains(minuteOfDay: 14 * 60))
        #expect(!QuietHours(startMinute: 600, endMinute: 600).contains(minuteOfDay: 600))
    }

    @Test func theNextAllowedMomentIsTheEndOfTheQuiet() {
        let quiet = QuietHours.standard
        #expect(quiet.nextAllowed(after: Fixtures.date(2026, 10, 12, 23), calendar: Fixtures.utc) == Fixtures.date(2026, 10, 13, 9))
        #expect(quiet.nextAllowed(after: Fixtures.date(2026, 10, 12, 14), calendar: Fixtures.utc) == Fixtures.date(2026, 10, 12, 14))
    }

    // MARK: - Routine

    @Test func theRoutineRingsOnItsDaysAtItsTime() {
        // Monday, Wednesday and Friday at 18:00, from Monday 12 October 14:00 for a week.
        let routine = CreationRoutine(weekdays: [2, 4, 6], hour: 18, minute: 0)
        let times = routine.occurrences(after: Fixtures.monday, until: Fixtures.monday + Fixtures.days(7), calendar: Fixtures.utc)
        #expect(times == [Fixtures.date(2026, 10, 12, 18), Fixtures.date(2026, 10, 14, 18), Fixtures.date(2026, 10, 16, 18)])
    }
}
