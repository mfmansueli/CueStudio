//
//  NotificationState.swift
//  Cue Studio
//

import Foundation

/// Everything the notifications keep on this iPhone (`NotificationStateStore`): the creator's choices, their reminders and routine, and
/// the history the caps and the discovery need. Versioned (`schema`), and every field is read with a default, so a state written by an
/// older or newer build opens; a damaged one starts over (`NotificationStateStore`), without inventing any history.
nonisolated struct NotificationState: Codable, Hashable, Sendable {
    static let currentSchema = 1
    /// Taps remembered so a repeated callback never opens twice.
    static let handledMemory = 50
    /// History older than this is dropped: the longest rule looks back 90 days.
    static let historyDays = 120

    var schema = Self.currentSchema
    /// When this install first ran the notifications. Projects older than this wait from here, not from when they were made, so updating
    /// the app never sends every old draft at once.
    var startedAt: Date
    /// Only the creator's own choices; a category never chosen is `isOnByDefault`.
    var consent: [String: Bool] = [:]
    var quietHours = QuietHours.standard
    /// Automatic notifications are paused until then (7 or 30 days).
    var pausedUntil: Date?
    /// The project's title in a notification's text. Off: notifications say "your script", never what it is called.
    var showsTitles = false
    var reminders: [Reminder] = []
    var routine: CreationRoutine?
    var automatic: [AutomaticRecord] = []
    var exposures: [FeatureExposure] = []
    /// Tools seen used for real (`FeatureID.rawValue` → when Cue first noticed): their introductions stop.
    var adopted: [String: Date] = [:]
    /// Uses only an event can tell (Voice Following played, a remote connected, the universe visited, an idea used).
    var used: [String: Date] = [:]
    /// "Don't suggest this": never introduced again.
    var notInterested: [String] = []
    /// "Not now": not before then.
    var snoozedFeatures: [String: Date] = [:]
    /// The last time the creator worked in Cue (opened it, wrote, recorded, edited, shared).
    var lastActivity: Date?
    /// The version that ran last, for "What's new" (an update, never a fresh install).
    var lastSeenVersion: String?
    /// The version Cue was updated from, when this one came as an update; nil on a fresh install.
    var updatedFromVersion: String?
    var announcedWhatsNew: [String] = []
    var announcedYearReviews: [Int] = []
    var handledInteractions: [String] = []
    var attribution: AttributionContext?
    /// Local counts per campaign and outcome ("discover.cleanUp.opened"), for Debug and for builds that can't send numbers.
    var counters: [String: Int] = [:]
    /// The interface language the scheduled texts were written in: a new one writes them again.
    var contentLanguage: String?
    /// A tool whose notification arrived while the creator was recording or editing: introduced in the app at the next quiet moment.
    var deferredIntro: FeatureID?
    /// What each pending request of Cue's says and when (`requestID` → signature): unchanged ones aren't handed to the system again.
    var scheduledSignatures: [String: String] = [:]
    /// When an "eligible" or "suppressed" was last counted for a request, so a plan made many times a day counts it once a day.
    var recentMeasures: [String: Date] = [:]

    init(startedAt: Date) {
        self.startedAt = startedAt
    }

    func isOn(_ category: NotificationCategory) -> Bool {
        consent[category.rawValue] ?? category.isOnByDefault
    }

    func isPaused(at now: Date) -> Bool {
        guard let pausedUntil else { return false }
        return pausedUntil > now
    }

    func isNotInterested(in feature: FeatureID) -> Bool { notInterested.contains(feature.rawValue) }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case schema, startedAt, consent, quietHours, pausedUntil, showsTitles, reminders, routine, automatic, exposures
        case adopted, used, notInterested, snoozedFeatures, lastActivity, lastSeenVersion, updatedFromVersion, announcedWhatsNew, announcedYearReviews
        case handledInteractions, attribution, counters, contentLanguage, deferredIntro, scheduledSignatures, recentMeasures
    }

    /// Every field has a default; a list that holds one entry this build can't read (a newer campaign) drops only that entry.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decodeIfPresent(Int.self, forKey: .schema) ?? Self.currentSchema
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? .now
        consent = (try? container.decodeIfPresent([String: Bool].self, forKey: .consent)) ?? [:]
        quietHours = (try? container.decodeIfPresent(QuietHours.self, forKey: .quietHours)) ?? .standard
        pausedUntil = try? container.decodeIfPresent(Date.self, forKey: .pausedUntil)
        showsTitles = (try? container.decodeIfPresent(Bool.self, forKey: .showsTitles)) ?? false
        reminders = Self.lenient(Reminder.self, container, .reminders)
        routine = try? container.decodeIfPresent(CreationRoutine.self, forKey: .routine)
        automatic = Self.lenient(AutomaticRecord.self, container, .automatic)
        exposures = Self.lenient(FeatureExposure.self, container, .exposures)
        adopted = (try? container.decodeIfPresent([String: Date].self, forKey: .adopted)) ?? [:]
        used = (try? container.decodeIfPresent([String: Date].self, forKey: .used)) ?? [:]
        notInterested = (try? container.decodeIfPresent([String].self, forKey: .notInterested)) ?? []
        snoozedFeatures = (try? container.decodeIfPresent([String: Date].self, forKey: .snoozedFeatures)) ?? [:]
        lastActivity = try? container.decodeIfPresent(Date.self, forKey: .lastActivity)
        lastSeenVersion = try? container.decodeIfPresent(String.self, forKey: .lastSeenVersion)
        updatedFromVersion = try? container.decodeIfPresent(String.self, forKey: .updatedFromVersion)
        announcedWhatsNew = (try? container.decodeIfPresent([String].self, forKey: .announcedWhatsNew)) ?? []
        announcedYearReviews = (try? container.decodeIfPresent([Int].self, forKey: .announcedYearReviews)) ?? []
        handledInteractions = (try? container.decodeIfPresent([String].self, forKey: .handledInteractions)) ?? []
        attribution = try? container.decodeIfPresent(AttributionContext.self, forKey: .attribution)
        counters = (try? container.decodeIfPresent([String: Int].self, forKey: .counters)) ?? [:]
        contentLanguage = try? container.decodeIfPresent(String.self, forKey: .contentLanguage)
        deferredIntro = try? container.decodeIfPresent(FeatureID.self, forKey: .deferredIntro)
        scheduledSignatures = (try? container.decodeIfPresent([String: String].self, forKey: .scheduledSignatures)) ?? [:]
        recentMeasures = (try? container.decodeIfPresent([String: Date].self, forKey: .recentMeasures)) ?? [:]
    }

    /// The entries of a list that this build can read.
    private static func lenient<Element: Decodable>(
        _ type: Element.Type, _ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
    ) -> [Element] {
        guard let entries = try? container.decodeIfPresent([LenientEntry<Element>].self, forKey: key) else { return [] }
        return entries.compactMap(\.value)
    }

    /// Decodes an element, or nothing when it can't be read, without failing the list.
    private struct LenientEntry<Element: Decodable>: Decodable {
        let value: Element?

        init(from decoder: Decoder) throws {
            value = try? Element(from: decoder)
        }
    }
}
