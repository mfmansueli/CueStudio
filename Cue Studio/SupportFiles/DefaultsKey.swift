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
    /// How big the script's text is while writing (`ScriptTextSize` raw value).
    static let scriptEditorTextSize = "scriptEditorTextSize"
    /// The type the creator saved as "My style" in Quick edit (`TextLook`, JSON).
    static let myTextStyle = "myTextStyle"
    /// The cover style the creator saved as "My cover style" (`CoverLook`, JSON).
    static let myCoverStyle = "myCoverStyle"
    /// Free exports used, before the count moved to the Keychain; migrated and removed at launch.
    static let legacyCleanExportsUsed = "cleanExportsUsed"
    /// How the Takes tab lays videos out (`TakeLayout` raw value); absent = the grid.
    static let takesLayout = "takesLayout"
    /// The Sign in with Apple account (ID, and the name and email Apple shared once).
    static let appleAccount = "appleAccount"
    /// Settings › Personalize: the sky (`SkyDensity` raw value; absent = calm), the story moments, the
    /// haptics and the automatic topic tag (absent = on).
    static let skyDensity = "skyDensity"
    static let celebrations = "celebrations"
    static let hapticsEnabled = "hapticsEnabled"
    static let autoTagTopics = "autoTagTopics"
    /// The first flight (onboarding) is over, and its "first star" has been told.
    static let onboardingCompleted = "onboardingCompleted"
    static let firstStarShown = "firstStarShown"
    /// The videos shared (once each), the day of the first one, and the milestones already told.
    static let sharedTakeIDs = "sharedTakeIDs"
    static let firstShareDate = "firstShareDate"
    static let celebratedMilestones = "celebratedMilestones"
    /// The Logbook's ideas (JSON).
    static let logbook = "logbook"
    /// v1's monthly AI counters ("aiScriptsUsed_2026-09"), removed at launch.
    static let legacyAIScriptsUsedPrefix = "aiScriptsUsed_"
}
