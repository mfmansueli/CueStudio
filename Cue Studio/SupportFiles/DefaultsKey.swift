//
//  DefaultsKey.swift
//  Cue Studio
//

import Foundation

/// Every UserDefaults key in one place, so no screen repeats a raw string.
nonisolated enum DefaultsKey {
    static let prompterSettings = "prompterSettings"
    static let cameraSettings = "cameraSettings"
    /// The language Voice Following listens for (`CueLanguage` raw value); absent = the script's.
    static let voiceFollowingLanguage = "voiceFollowingLanguage"
    /// The language new scripts are written in (`CueLanguage` raw value); absent = auto-detect.
    static let scriptLanguage = "scriptLanguage"
    /// The Selfie reading line's first-time tip was dismissed. The tip is gone; removed at launch.
    static let legacyReadingLineTipSeen = "readingLineTipSeen"
    static let creatorProfile = "creatorProfile"
    /// The type the creator saved as "My style" in Quick edit (`TextLook`, JSON).
    static let myTextStyle = "myTextStyle"
    /// Free exports used, before the count moved to the Keychain; migrated and removed at launch.
    static let legacyCleanExportsUsed = "cleanExportsUsed"
    /// The Sign in with Apple account (ID, and the name and email Apple shared once).
    static let appleAccount = "appleAccount"
    /// v1's monthly AI counters ("aiScriptsUsed_2026-09"), removed at launch.
    static let legacyAIScriptsUsedPrefix = "aiScriptsUsed_"
}
