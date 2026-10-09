//
//  NotificationPayload.swift
//  Cue Studio
//

import Foundation

/// What a scheduled notification carries in its `userInfo`, as one JSON string: why it was sent and where it goes. No title, script,
/// comment or anything the creator wrote is in it; only kinds and IDs. Versioned: a payload from a newer build (or a damaged one)
/// is refused and the tap opens Cue as it is.
nonisolated struct NotificationPayload: Codable, Hashable, Sendable {
    static let currentVersion = 1
    /// The `userInfo` key of the JSON.
    static let userInfoKey = "cue.payload"

    var version = Self.currentVersion
    var campaign: NotificationCampaign
    var feature: FeatureID?
    var destination: NotificationDestination
    /// The project it is about (`ProjectKey`), so one tap can cancel the rest of that project's nudges.
    var projectKey: String?
    var reminderID: UUID?

    var category: NotificationCategory { campaign.category }

    /// "discover.cleanUp", "projects.readyToRecord": what measurement calls it.
    var campaignName: String {
        if let feature { return "discover.\(feature.rawValue)" }
        return "\(category.rawValue).\(campaign.rawValue)"
    }

    func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    /// The payload of a notification, or nil when it isn't Cue's, is damaged, or comes from a version this build doesn't read.
    static func decode(_ text: String?) -> NotificationPayload? {
        guard let text, let data = text.data(using: .utf8),
              let payload = try? JSONDecoder().decode(NotificationPayload.self, from: data),
              (1...currentVersion).contains(payload.version)
        else { return nil }
        return payload
    }
}
