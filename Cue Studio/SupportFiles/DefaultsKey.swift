//
//  DefaultsKey.swift
//  Cue Studio
//

import Foundation

/// Every UserDefaults key in one place, so no screen repeats a raw string.
nonisolated enum DefaultsKey {
    static let prompterSettings = "prompterSettings"
    static let cameraSettings = "cameraSettings"
    /// The Selfie reading line's first-time tip was dismissed. The tip is gone; removed at launch.
    static let legacyReadingLineTipSeen = "readingLineTipSeen"
    static let creatorProfile = "creatorProfile"
    /// Free exports used, before the count moved to the Keychain; migrated and removed at launch.
    static let legacyCleanExportsUsed = "cleanExportsUsed"
    /// The Sign in with Apple account (ID, and the name and email Apple shared once).
    static let appleAccount = "appleAccount"
    /// v1's monthly AI counters ("aiScriptsUsed_2026-09"), removed at launch.
    static let legacyAIScriptsUsedPrefix = "aiScriptsUsed_"
    /// Language & Region: Cue's interface language ("pt-BR"); absent follows the iPhone.
    static let appLanguage = "appLanguage"
    /// Language & Region: what Voice Following listens for ("script" or a language).
    static let voiceFollowingLanguage = "voiceFollowingLanguage"
    /// Language & Region: the language new scripts start in; absent is Auto-detect.
    static let scriptLanguage = "scriptLanguage"
    /// The system's own per-app language list (Settings › Cue › Language writes it too).
    static let appleLanguages = "AppleLanguages"
}
