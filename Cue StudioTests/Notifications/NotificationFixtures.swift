//
//  NotificationFixtures.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Fixed calendars, moments and made-up projects for the notification tests: nothing reads the real clock or time zone.
enum NotificationFixtures {
    static func calendar(_ zone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static let utc = calendar()

    /// A moment on `calendar`'s clock.
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, in calendar: Calendar = utc) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    /// Monday 12 October 2026, 14:00 UTC: outside the quiet hours.
    static let monday = date(2026, 10, 12, 14)

    static func hours(_ count: Double) -> TimeInterval { count * 3600 }

    static func days(_ count: Double) -> TimeInterval { count * 86_400 }

    static func candidate(
        _ campaign: NotificationCampaign = .readyToRecord, feature: FeatureID? = nil, project: String = UUID().uuidString,
        earliest: Date = monday
    ) -> CampaignCandidate {
        CampaignCandidate(
            campaign: campaign, feature: feature, projectKey: project, earliest: earliest, destination: .scripts,
            subject: feature.map { NotificationSubject.feature($0) } ?? .project(campaign, title: "", network: nil)
        )
    }

    static func context(now: Date = monday, calendar: Calendar = utc) -> PlanningContext {
        var context = PlanningContext(now: now, calendar: calendar)
        context.policy.minimumLead = 0
        return context
    }

    static func sent(_ fireDate: Date, campaign: NotificationCampaign = .readyToRecord, feature: FeatureID? = nil) -> AutomaticRecord {
        AutomaticRecord(
            requestID: UUID().uuidString, campaign: campaign, feature: feature, projectKey: UUID().uuidString, fireDate: fireDate, status: .sent
        )
    }

    static func script(
        _ state: ScriptState, id: UUID = UUID(), words: Int = 40, updatedAt: Date = monday, createdAt: Date? = nil,
        language: CueLanguage? = .english, platform: Platform = .tiktok
    ) -> NotificationFacts.ScriptFact {
        NotificationFacts.ScriptFact(
            id: id, title: "Morning habits", state: state, wordCount: words, createdAt: createdAt ?? updatedAt, updatedAt: updatedAt,
            language: language, platform: platform
        )
    }

    static func take(
        id: UUID = UUID(), scriptID: UUID?, recordedAt: Date = monday, stage: TakeStage = .ready, exported: Bool = false,
        duration: TimeInterval = 30, captions: Bool = false, analyzed: Bool = false, tools: Set<FeatureID> = [],
        language: CueLanguage? = .english, platform: Platform? = .tiktok
    ) -> NotificationFacts.TakeFact {
        NotificationFacts.TakeFact(
            id: id, scriptID: scriptID, title: "Morning habits", recordedAt: recordedAt, duration: duration, stage: stage,
            isExported: exported, videoExported: exported, platform: platform, language: language, hasCaptions: captions,
            cleanUpAnalyzed: analyzed, toolsUsed: tools
        )
    }
}
