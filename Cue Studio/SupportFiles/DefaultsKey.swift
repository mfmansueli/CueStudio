//
//  DefaultsKey.swift
//  Cue Studio
//

import Foundation

/// Every UserDefaults key in one place, so no screen repeats a raw string.
nonisolated enum DefaultsKey {
    static let prompterSettings = "prompterSettings"
    /// The reading line saved before v30 that sat low enough to put the text box in the middle of the screen was cleared once.
    static let readingLineResetV30 = "readingLineResetV30"
    static let cameraSettings = "cameraSettings"
    /// The language Voice Following listens for (`CueLanguage` raw value); absent = the script's.
    static let voiceFollowingLanguage = "voiceFollowingLanguage"
    /// The language new scripts are written in (`CueLanguage` raw value); absent = auto-detect.
    static let scriptLanguage = "scriptLanguage"
    /// The Selfie reading line's first-time tip was dismissed. The tip is gone; removed at launch.
    static let legacyReadingLineTipSeen = "readingLineTipSeen"
    static let creatorProfile = "creatorProfile"
    /// The card's suggested ideas written by the model and not yet shown, and the titles of the ones that were (`IdeaSuggestionService`).
    static let ideaSuggestions = "ideaSuggestions"
    /// The creator's own cues on the script page's cues bar (`[String]`).
    static let customCues = "customCues"
    /// The script page's Cues switch (`Bool`; absent = on).
    static let showsCuesOnPage = "showsCuesOnPage"
    /// The text size of the old full script editor ("Versions & options"). The editor is gone; removed at launch.
    static let legacyScriptEditorTextSize = "scriptEditorTextSize"
    /// The type the creator saved as "My style" in Quick edit (`TextLook`, JSON).
    static let myTextStyle = "myTextStyle"
    /// The cover style the creator saved as "My cover style" (`CoverLook`, JSON).
    static let myCoverStyle = "myCoverStyle"
    /// Free exports used, before the count moved to the Keychain; migrated and removed at launch.
    static let legacyCleanExportsUsed = "cleanExportsUsed"
    /// Debug builds: this install has launched before. UserDefaults goes with the app and the Keychain stays, so without
    /// it the launch is a new install's first, and the free exports start over (`UsageQuotaService`).
    static let installLaunched = "installLaunched"
    /// How the Takes tab lays videos out (`TakeLayout` raw value); absent = the grid.
    static let takesLayout = "takesLayout"
    /// The Sign in with Apple account (ID, and the name and email Apple shared once).
    static let appleAccount = "appleAccount"
    /// Settings › Personalize: the sky (`SkyDensity` raw value; absent = Calm), the story moments, the
    /// haptics and the automatic topic tag (absent = on).
    static let skyDensity = "skyDensity"
    static let celebrations = "celebrations"
    /// The colour of the universe's core (`CoreColor` raw value; absent = gold).
    static let coreColor = "coreColor"
    static let hapticsEnabled = "hapticsEnabled"
    static let autoTagTopics = "autoTagTopics"
    /// The first flight (onboarding) is over, and its "first star" has been told.
    static let onboardingCompleted = "onboardingCompleted"
    static let firstStarShown = "firstStarShown"
    /// The videos shared (once each), the day of the first one, and the milestones already told.
    static let sharedTakeIDs = "sharedTakeIDs"
    static let firstShareDate = "firstShareDate"
    /// The same videos with date, platform and topic (`[ShareRecord]`, JSON); the universe of each year is built from them.
    static let shareRecords = "shareRecords"
    /// The "Share to universe" queues not yet finished (`[ShareQueue]`, JSON) and how many times the "Posting to n networks" explanation was shown.
    static let shareQueues = "shareQueues"
    static let queueExplainerShown = "queueExplainerShown"
    /// How many videos each planet had when "Your universe" was last open (`[String: Int]`, "2026.tiktok"): the planets grow from there.
    static let seenPlanetCounts = "seenPlanetCounts"
    static let celebratedMilestones = "celebratedMilestones"
    /// "Your stars" in the sky above Scripts (`[StarPoint]`, JSON, up to 50) and how many were ever added.
    static let skyMemory = "skyMemory"
    static let skyMemoryAdded = "skyMemoryAdded"
    /// What the My Cue Voice tip remembers (`VoiceQuestionState`, JSON): days opened, tips shown, snoozes, skips.
    static let voiceQuestionState = "vq.state"
    /// The Logbook's ideas (JSON).
    static let logbook = "logbook"
    /// Settings › Privacy & AI data: Apple Intelligence on or off (absent = on) and the anonymous usage switch (absent = off).
    static let onDeviceAI = "onDeviceAI"
    static let helpImproveCue = "helpImproveCue"
    /// The notifications: the creator's choices, reminders and routine, and the history the caps read (`NotificationState`, JSON).
    static let notificationState = "notifications.state"
    /// v1's monthly AI counters ("aiScriptsUsed_2026-09"), removed at launch.
    static let legacyAIScriptsUsedPrefix = "aiScriptsUsed_"
}
