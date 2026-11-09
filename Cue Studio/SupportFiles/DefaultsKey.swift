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
    /// How many scripts have been written with the creator's catchphrases: whose turn it is (`CatchphraseRotation`).
    static let catchphraseTurn = "catchphraseTurn"
    /// Who writes the Scripts dock's next idea (`ScriptEngine` raw value): the creator's last pick on the writer chip; absent = Apple Intelligence.
    static let dockWriter = "dockWriter"
    /// The dock's idea, its brief and the card's choices (`DockDraft`), as the creator left them.
    static let dockDraft = "dockDraft"
    /// The card's suggested ideas written by the model and not yet shown, and the titles of the ones that were (`IdeaSuggestionService`).
    static let ideaSuggestions = "ideaSuggestions"
    /// The concrete subjects of each topic's ideas, a week at a time (`IdeaIngredientStore`).
    static let ideaIngredients = "ideaIngredients"
    /// The library has held a script at least once (`LibraryHistory`): an empty Scripts is then the returning state, not the first-use one.
    static let hasEverHadScript = "hasEverHadScript"
    /// The creator's own cues on the script page's cues bar (`[String]`).
    static let customCues = "customCues"
    /// The script page's Cues switch (`Bool`; absent = on).
    static let showsCuesOnPage = "showsCuesOnPage"
    /// Takes with an export running now (`[String]` of take ids).
    static let exportsInFlight = "exportsInFlight"
    /// Takes whose export was still running when Cue last stopped (`[String]` of take ids), until their review says so.
    static let stoppedExports = "stoppedExports"
    /// The text size of the old full script editor ("Versions & options"). The editor is gone; removed at launch.
    static let legacyScriptEditorTextSize = "scriptEditorTextSize"
    /// The type the creator saved as "My style" in Quick edit (`TextLook`, JSON).
    static let myTextStyle = "myTextStyle"
    /// The cover style the creator saved as "My cover style" (`CoverLook`, JSON).
    static let myCoverStyle = "myCoverStyle"
    /// Cover Studio's "My cover style" (`CoverStyle`).
    static let myCoverStudioStyle = "myCoverStudioStyle"
    /// The captions' "My style" in Quick edit (`MyCaptionStyle`, JSON), before saved styles: read once into
    /// `captionStyleLibrary` and kept for an earlier version of Cue.
    static let myCaptionStyle = "myCaptionStyle"
    /// The creator's saved styles (`StyleLibrary`, JSON): captions (`MyCaptionStyle`), texts (`TextLook`) and covers
    /// (`CoverStyle`), with favorites and the style new work starts in.
    static let captionStyleLibrary = "styles.captions"
    static let textStyleLibrary = "styles.texts"
    static let coverStyleLibrary = "styles.covers"
    /// Caption style › Styles' filter (`CaptionCatalogFilter` raw value).
    static let captionCatalogFilter = "styles.captions.filter"
    /// My words: the creator's names and terms that speech recognition listens for (`[String]`, `MyWordsStore`). Never the AI
    /// writing profile (My Cue Voice).
    static let myWords = "speech.myWords"
    /// Quick edit › Voice-over's "Show script" (`Bool`; absent = on) and the speed it scrolls at (`PrompterSettings.speed`'s scale;
    /// absent = the prompter's), `EditorPreferencesStore`.
    static let narrationScriptShown = "editor.narrationScriptShown"
    static let narrationScriptSpeed = "editor.narrationScriptSpeed"
    /// Quick edit's safe zone guide drawn over the preview (Aspect ratio › Safe zones); off until turned on, on every video after.
    static let safeGuideShown = "editor.safeGuideShown"
    /// When the editor last said Low Power Mode was on (`LowPowerNotice`: once a day).
    static let lowPowerNoticeShownAt = "editor.lowPowerNoticeShownAt"
    /// The timeline's current track for each take edited lately (`[String]` of "take id=track", the last edited at the end;
    /// `EditorPreferencesStore`).
    static let timelineLanes = "editor.timelineLanes"
    /// The takes the kit for new videos already went on once (`[String]` of take ids, the last at the end; `EditorPreferencesStore`).
    static let newVideoKitTakes = "editor.newVideoKitTakes"
    /// What Copy and Paste look remember for each take edited lately (JSON list, the last at the end; `EditorPreferencesStore`).
    static let rememberedLooks = "editor.rememberedLooks"
    /// Free exports used, before the count moved to the Keychain; migrated and removed at launch.
    static let legacyCleanExportsUsed = "cleanExportsUsed"
    /// Debug builds: this install has launched before. UserDefaults goes with the app and the Keychain stays, so without
    /// it the launch is a new install's first, and the free exports start over (`UsageQuotaService`).
    static let installLaunched = "installLaunched"
    /// Take videos whose deletion was decided and hasn't finished (`PendingTakeDeletions`).
    static let takeDeletionsPending = "takeDeletionsPending"
    /// When each take video nothing names was first found so (`[String: Date]`, `TakeOrphanSweep`).
    static let takeOrphanSightings = "takeOrphanSightings"
    /// Copies a failed import left in the edits' media that couldn't be removed then (`EditMediaFiles.discardPartial`).
    static let editMediaDeletionsPending = "editMediaDeletionsPending"
    /// How the Takes tab lays videos out (`TakeLayout` raw value); absent = the grid.
    static let takesLayout = "takesLayout"
    /// The quality last picked in Export options (`ExportQuality` raw value; absent = the recording's own).
    static let exportQuality = "exportQuality"
    /// Personalize was opened once: its NEW badge in Settings is gone.
    static let personalizeSeen = "personalizeSeen"
    /// The account Sign in with Apple kept before it was removed (Apple's user identifier, and the name and email Apple shared once): only
    /// erased now (`AppleSignInLeftovers`).
    static let legacyAppleAccount = "appleAccount"
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
    /// The chapter a first flight was left on after 1.4 kept its script (`OnboardingService`): it resumes there.
    static let onboardingStep = "onboardingStep"
    static let firstStarShown = "firstStarShown"
    /// The take whose first star waits for Takes (`OnboardingService.keepFirstStar`, D4).
    static let firstStarWaitingTake = "firstStarWaitingTake"
    /// The first voyage's own marks (`VoyageMarks`, JSON): its stage, the practice, a skipped Polish, tips closed, segments lit.
    static let firstVoyage = "firstVoyage"
    /// The words Cue drafted for each script, until it is recorded (`DraftLearningService`).
    static let cueDrafts = "cueDrafts"
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
    /// "Your stars" (up to 50, and how many were ever added), which earlier versions kept: only "Delete my Cue data" still removes them.
    static let skyMemory = "skyMemory"
    static let skyMemoryAdded = "skyMemoryAdded"
    /// What the My Cue Voice tip remembers (`VoiceQuestionState`, JSON): days opened, tips shown, snoozes, skips.
    static let voiceQuestionState = "vq.state"
    /// The My Cue Voice tips' generation, raised by "Delete my Cue data" (`VoiceQuestionScheduler.tipGeneration`); never erased.
    static let voiceTipGeneration = "vq.tipGeneration"
    /// The Logbook's ideas (JSON).
    static let logbook = "logbook"
    /// The words left in the Logbook's field when it closed, there again when it opens.
    static let logbookDraft = "logbookDraft"
    /// How many times each teaching note of the editor was shown (`PanelNoteMemory`), by a digest of its words.
    static let panelNotesRead = "panelNotesRead"
    /// Settings › Privacy & AI data: Apple Intelligence on or off (absent = on) and "Help improve Cue", usage data and crash reports (absent = off).
    static let onDeviceAI = "onDeviceAI"
    static let helpImproveCue = "helpImproveCue"
    /// The notifications: the creator's choices, reminders and routine, and the history the caps read (`NotificationState`, JSON).
    static let notificationState = "notifications.state"
    /// When Cue may ask for an App Store rating: the install day, videos delivered, the version asked in, the last failure (`ReviewPromptPolicy`, JSON).
    static let reviewPrompt = "reviewPrompt.v1"
    /// v1's monthly AI counters ("aiScriptsUsed_2026-09"), removed at launch.
    static let legacyAIScriptsUsedPrefix = "aiScriptsUsed_"
}
