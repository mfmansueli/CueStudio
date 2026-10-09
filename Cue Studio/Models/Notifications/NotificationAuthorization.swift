//
//  NotificationAuthorization.swift
//  Cue Studio
//

import Foundation

/// What iOS lets Cue do, read from the system each time Cue becomes active (it changes in Settings, outside Cue). Separate from the
/// categories: allowed by iOS and turned on in Cue are both needed for a notification.
nonisolated enum NotificationAuthorization: String, Codable, Sendable {
    /// Cue hasn't asked yet: it asks when the creator sets a reminder or turns a category on, never at launch.
    case notDetermined
    /// Off in iOS Settings. Cue never asks again (iOS wouldn't show the question); Open Settings is the creator's to tap.
    case denied
    case authorized
    /// Delivered quietly to Notification Center, without a banner or sound, until the creator chooses.
    case provisional
    /// App Clips only; treated as allowed.
    case ephemeral

    /// Something can be scheduled and will reach Notification Center.
    var canSchedule: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral: true
        case .notDetermined, .denied: false
        }
    }
}
