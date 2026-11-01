//
//  IdeaCalendarTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The occasions ideas may be tied to (`IdeaCalendar`): the right day where the creator lives, only in the weeks before it, and none without a
/// region.
struct IdeaCalendarTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func days(_ kind: IdeaOccasion.Kind, _ year: Int, in region: String?) -> [Date] {
        IdeaCalendar.days(of: kind, year: year, region: region, calendar: calendar)
    }

    // MARK: - The days

    @Test func easterAndWhatHangsOnItFallOnTheirDays() {
        #expect(IdeaCalendar.easter(year: 2026, calendar: calendar) == day(2026, 4, 5))
        #expect(IdeaCalendar.easter(year: 2027, calendar: calendar) == day(2027, 3, 28))
        #expect(days(.carnival, 2026, in: "BR") == [day(2026, 2, 17)])
        #expect(days(.mothersDay, 2026, in: "GB") == [day(2026, 3, 15)], "Mothering Sunday, three weeks before Easter")
    }

    @Test func mothersAndFathersDayMoveWithTheCountry() {
        #expect(days(.mothersDay, 2026, in: "BR") == [day(2026, 5, 10)])
        #expect(days(.mothersDay, 2026, in: "US") == [day(2026, 5, 10)])
        #expect(days(.mothersDay, 2026, in: "PT") == [day(2026, 5, 3)])
        #expect(days(.mothersDay, 2026, in: "MX") == [day(2026, 5, 10)])
        #expect(days(.mothersDay, 2026, in: "FR") == [day(2026, 5, 31)])
        #expect(days(.fathersDay, 2026, in: "BR") == [day(2026, 8, 9)])
        #expect(days(.fathersDay, 2026, in: "US") == [day(2026, 6, 21)])
        #expect(days(.fathersDay, 2026, in: "IT") == [day(2026, 3, 19)])
        #expect(days(.fathersDay, 2026, in: "KR").isEmpty, "Korea keeps one Parents' Day")
        #expect(days(.valentines, 2026, in: "BR") == [day(2026, 6, 12)], "Dia dos Namorados")
        #expect(days(.valentines, 2026, in: "US") == [day(2026, 2, 14)])
    }

    @Test func blackFridayIsTheDayAfterThanksgiving() {
        #expect(days(.thanksgiving, 2026, in: "US") == [day(2026, 11, 26)])
        #expect(days(.blackFriday, 2026, in: "BR") == [day(2026, 11, 27)])
        #expect(days(.blackFriday, 2027, in: "DE") == [day(2027, 11, 26)])
        #expect(days(.blackFriday, 2026, in: "SA").isEmpty)
        #expect(days(.christmas, 2026, in: "JP") == [day(2026, 12, 25)])
    }

    @Test func theLunarAndIslamicFestivalsComeFromTheirCalendars() throws {
        #expect(days(.lunarNewYear, 2026, in: "CN") == [day(2026, 2, 17)])
        #expect(days(.midAutumn, 2026, in: "KR") == [day(2026, 9, 25)])
        let ramadan = try #require(days(.ramadan, 2026, in: "SA").first)
        let distance = try #require(calendar.dateComponents([.day], from: day(2026, 2, 18), to: ramadan).day)
        #expect(abs(distance) <= 1, "Ramadan 1447 starts around February 18, 2026")
        #expect(days(.lunarNewYear, 2026, in: "BR").isEmpty)
        #expect(days(.ramadan, 2026, in: "BR").isEmpty)
    }

    // MARK: - Near a day

    @Test func anOccasionIsSuggestedOnlyInTheWeeksBeforeIt() {
        let april = IdeaCalendar.occasions(near: day(2026, 4, 25), region: "BR", calendar: calendar)
        #expect(april.map(\.kind) == [.mothersDay])
        #expect(april.first?.promptWhen == "on May 10")
        #expect(IdeaCalendar.occasions(near: day(2026, 4, 10), region: "BR", calendar: calendar).isEmpty, "a month ahead is too early")
        let november = IdeaCalendar.occasions(near: day(2026, 11, 10), region: "US", calendar: calendar)
        #expect(november.map(\.kind) == [.thanksgiving, .blackFriday])
    }

    @Test func aSeasonIsSaidAsComingUpNeverAsADay() throws {
        let january = IdeaCalendar.occasions(near: day(2026, 1, 10), region: "BR", calendar: calendar)
        let school = try #require(january.first { $0.kind == .backToSchool })
        #expect(school.isApproximate)
        #expect(school.promptWhen == "coming up")
        let late = IdeaCalendar.occasions(near: day(2026, 2, 6), region: "BR", calendar: calendar)
        #expect(late.contains { $0.kind == .backToSchool }, "a season stays a few days after it starts")
    }

    @Test func withoutARegionThereIsNoOccasion() {
        #expect(IdeaCalendar.occasions(near: day(2026, 12, 20), region: nil, calendar: calendar).isEmpty)
        #expect(IdeaCalendar.occasions(near: day(2026, 12, 20), region: "XX", calendar: calendar).map(\.kind) == [.christmas, .newYear])
    }

    @Test func everyOccasionHasANameAndAPromptName() {
        for kind in IdeaOccasion.Kind.allCases {
            let occasion = IdeaOccasion(kind: kind, date: day(2026, 1, 1), isApproximate: false)
            #expect(!occasion.name.isEmpty && !occasion.promptName.isEmpty)
        }
    }
}
