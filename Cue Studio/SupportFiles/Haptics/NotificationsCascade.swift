//
//  NotificationsCascade.swift
//  Cue Studio
//

import Foundation

/// The moment notifications are allowed in Settings › Notifications: the bell rings and takes its ✓, and the switches below light one after
/// another (in time with `HapticPatterns.notificationsOn`).
enum NotificationsCascade {
    /// Seconds from iOS's yes to the first switch lighting, and between switches.
    static let firstSwitch: TimeInterval = 0.42
    static let step: TimeInterval = 0.14
}
