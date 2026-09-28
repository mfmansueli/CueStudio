//
//  DefaultsKey.swift
//  Cue Studio
//

import Foundation

/// Every UserDefaults key in one place, so no screen repeats a raw string.
nonisolated enum DefaultsKey {
    static let prompterSettings = "prompterSettings"
    static let cameraSettings = "cameraSettings"
    /// The Selfie reading line's first-time tip was dismissed.
    static let readingLineTipSeen = "readingLineTipSeen"
    static let creatorProfile = "creatorProfile"
    static let cleanExportsUsed = "cleanExportsUsed"
    /// The Sign in with Apple account (ID, and the name and email Apple shared once).
    static let appleAccount = "appleAccount"
    /// v1's monthly AI counters ("aiScriptsUsed_2026-09"), removed at launch.
    static let legacyAIScriptsUsedPrefix = "aiScriptsUsed_"
}
