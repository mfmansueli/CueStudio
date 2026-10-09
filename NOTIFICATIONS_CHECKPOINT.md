# Notifications — work checkpoint (branch `feature/notifications`)

Task: the full contextual notification + feature-discovery system (the long prompt: categories/consent, reminders, project campaigns,
discovery catalog, caps, routing, tests, `NOTIFICATIONS.md`). **Nothing has been built or tested yet.** Delete this file when done.

## Done (written, not compiled)

**Models** (`Cue Studio/Models/Notifications/`): `NotificationCategory` (5 categories; discovery/whatsNew off by default),
`NotificationCampaign` (category, priority 1–7, isAutomatic), `NotificationDestination` (typed, Codable), `NotificationPayload`
(versioned JSON in `userInfo["cue.payload"]`), `LocalDateTime` (floating wall clock; DST gap → next time, repeated hour → first),
`Reminder`, `ReminderSubject`, `ReminderChoice` (tonight 20:00 until 19:30, tomorrow 10:00, custom), `ReminderResult`, `CreationRoutine`,
`QuietHours` (21:00–09:00), `AutomaticRecord` (reserved/sent), `FeatureExposure`, `AttributionContext` (24 h), `NotificationState`
(versioned, lenient decoding), `NotificationAuthorization`, `SuppressionReason`, `NotificationOutcome`, `NotificationFacts`,
`NotificationSubject`, `CampaignCandidate`, `PlannedNotification`, `NotificationContent`, `LocalNotificationRequest`,
`NotificationInteraction`, `ForegroundPresentation`, `FeatureID`, `FeatureIntroRequest`, `NotificationTelemetryEvent`, `IdeaKey`,
`ProjectKey`, `NotificationIdentifier`. Also `Models/EditorTool.swift`.

**Pure rules** (`Managers/Notifications/Planning`, `Discovery`): `NotificationPolicy` (all caps/timings), `ProjectCampaigns` (one next
step per project + 2 return attempts), `PlanningContext`, `NotificationPlanner` (caps 1/24h, 2/7d, discovery 1/7d, feature 2/90d & 30d,
±12 h around user times, quiet hours, pause, tip day, return replaces others), `FeatureCatalog` (17 tools, data), `FeatureIntro`,
`FeatureRequirement`, `DiscoveryTarget`, `DiscoveryRules`, `FeatureAdoption`, `FeatureCopy`, `WhatsNewCatalog` (empty for 1.0),
`NotificationCopy`.

**Service** (`Managers/Notifications`): `NotificationService` (+`Reconcile`, `+Plan`, `+Reminders`, `+Discovery`, `+Opening`,
`+Metrics`), `NotificationStateStore`, `NotificationFactsSource` + `AppNotificationFacts`, `Center/NotificationCenterClient`,
`SystemNotificationCenter`, `NotificationCenterDelegate`, `NotificationRouter`. `TelemetryManager.record(NotificationTelemetryEvent)`
(Analytics event, only when "Help improve Cue" is on).

**Integration done**: `DefaultsKey.notificationState`; `ShareQueue.updatedAt` + `ShareQueueService(now:)`;
`IdeaSuggestionService.unseenModelIdeas` / `idea(forKey:)`; `PresentationService.profilePath` / `logbookFocus`; `ProfileRoute`;
`AppSheet.featureIntro/.voiceSetup/.importWriting`; `ReviewLaunchAction.editTool`; `SettingsRoute.notifications`; Settings entry/row/
destination/section; `VoiceQuestionScheduler.otherIntroductionToday` + `onTipShown`; `DataEraserService(notifications:)`;
`AppServices.notifications` + `makeNotifications` + `connectNotifications(tap:)` + environment; `LaunchOptions.notificationCenter` /
`notificationTap` (`-uiTestNotificationAuth`, `-uiTestNotificationTap`); Debug `InMemoryNotificationCenter`, `DebugNotificationTaps`.

**UI written**: `Screens/Main/Support/NotificationNavigator`, `Screens/Shared/Discovery/FeatureIntroSheet`,
`Screens/Shared/Reminders/ReminderSheet` + `ReminderFeedback`, `Screens/Settings/Notifications/` (`NotificationsSettingsView`,
`NotificationPermissionCard`, `NotificationRoutineEditor`, `NotificationReminderRow`, `NotificationDiagnosticsSection` (DEBUG)).

## Progress log (session 2)

- [x] 1. App init: delegate + `connectNotifications`.
- [x] 2. RootView: taps when ready; `Screens/Main/Support/NotificationTriggers` (scene phase, change triggers, time zone, remote use).
- [x] 3. MainView: `.featureIntro` / `.voiceSetup` / `.importWriting` sheets, Profile path, intro after a session, `recordUse(.ideas)`;
      `YourUniverseView(opensYearInReview:)` + `recordUse(.yourUniverse)`; navigator waits for a sheet to leave.
- [x] 4. `ReviewLaunchAction.editTool` → `QuickEditView(opening:)` → `QuickEditViewModel+Opening.open(_:)`; Adjust opens on a dial
      (`adjustOpensOn`).
- [x] 5. Remind me…: script page ••• (`ScriptDetailViewModel.Sheet.reminder`), Takes context menu, `ShareQueueStep` Post later menu
      (ids `shareFlow.postLater` → `shareFlow.noReminder` / `remindTonight` / `remindTomorrow` / `remindPick`); UI tests updated.
- [x] 6. `recordUse(.ideas)` in dock + IdeasSheet; export hooks (`TakeReviewViewModel.onExported`, `QuickEditExportModel.onFinished`);
      Logbook focus + yellow outline.
- [x] 7. `scripts/build.sh app` succeeds with zero warnings (FeatureCopy became `FeatureID+Copy.swift` computed properties; note text is
      `FeatureIntro.Note.text`; navigator/MainView switches split for SwiftLint).
- [ ] 8. Strings: batch 1 (Settings page, 34 keys) added. Remaining batches: reminders/sheets, notification copy, feature copy.
      Find what is still missing with the scratchpad-free check: `git diff main -U0` keys vs the catalog (see session notes).

## Left to do

1. `CueStudioApp.init`: `UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared` (after the unit-test guard,
   before scenes); call `services.connectNotifications(tap: options.notificationTap)`.
2. `RootView`: handle `NotificationRouter.shared.pending` when ready (`!onboarding.isActive`, `presentation.prompter == nil`,
   `!showsRemoteController`) → `notifications.open(_:)` → intro sheet or `NotificationNavigator.go(to:)`; scenePhase active →
   `appBecameActive()`, background → `appLeftScreen()`; `setNeedsReconcile` on scripts/takes count, share queues, logbook count;
   `rewritesTexts: true` on interface language and on `.NSSystemTimeZoneDidChange` (async `NotificationCenter.notifications(named:)`);
   `remote.state.isConnected` → `recordUse(.remoteControl)`.
3. `MainView`: sheet cases `.featureIntro` (Try it → `introAccepted` + navigator; Not now → `introSnoozed`; Don't suggest →
   `introDeclined`; `.onAppear introShown`), `.voiceSetup` (`VoiceSetupSheet(mode: .missing, …)`), `.importWriting`
   (`WritingImportSheet()`); Profile `NavigationStack(path: $presentation.profilePath)` + destination for `ProfileRoute`
   (`YourUniverseView` needs an `opensYearInReview` param); after the prompter closes → `inAppIntro(afterSession: true)`.
   In `NotificationNavigator.go`, wait ~450 ms after closing a sheet before opening the prompter cover.
4. `TakeReviewView`: `.editTool(tool)` → open `QuickEditView(take:services:opening:onClose:)`; add `QuickEditViewModel+Opening.swift`
   `open(_ tool:)` (cleanUp → `.pauses`, autoCaptions → `openCaptions()`, captionTranslation → captions + translation sheet,
   studioVoice → `.voice`, skinSmoothing → `.adjust` on the Skin Smoothing dial, background → `.background` with
   `lookScopeIsClip = false`, cover → `.cover`, media → `mediaInsertMode = .overlay; sheet = .media`, voiceOver → `.voiceOver`) after
   `prepare()`.
5. Reminder entry points: `ScriptPageMenu` "Remind me…" → `ReminderSheet(subject: .script(id))`; Takes context menu "Remind me…"
   (`.take(best.id)`); `ShareQueueStep` "Post later" → `Menu` (Tonight / Tomorrow / Pick a date and time… / No reminder; keep id
   `shareFlow.postLater`) — every choice calls `flow.postLater(network)`; update `ShareToUITests` / `HandoffCaptureTests` taps.
6. Events: `recordUse(.yourUniverse)` in `YourUniverseView.onAppear`; `recordUse(.ideas)` in `MainView` IdeasSheet callbacks and
   `ScriptsDock` after `suggestions.sent()`. Export completion: `TakeReviewViewModel` `onRendered` hook and `QuickEditExportModel`
   `onFinished` → `notifications.exportFinished(takeID:savedToPhotos:)`. `LogbookView`: scroll to / highlight `presentation.logbookFocus`.
7. Build with `scripts/build.sh`, fix compile errors (expect Swift 6 isolation issues in the delegate / `SystemNotificationCenter`;
   `import FirebaseAnalytics` must resolve), SwiftLint, zero warnings.
8. Strings: every new `String(localized:)` / `Text("…")` key in all 20 languages via `scripts/strings.py add`.
9. Tests (Swift Testing): planner caps/quiet/DST/exclusion/return/tip day, `ProjectCampaigns`, `DiscoveryRules`, `FeatureAdoption`,
   `LocalDateTime`, `ReminderChoice`, `QuietHours`, `NotificationState` migration/damage, `NotificationPayload` versions,
   `NotificationService` with `FakeNotificationCenter` + fake facts (reminders success/denied/failure/past, category off cancels,
   erase, open dedup/invalid, attribution, foreground busy), `NotificationRouter`, `ShareQueue.updatedAt`, `PaletteContrastTests` if a
   token is added. XCUITest: `NotificationsUITests` (settings page, denied card, reminder from script page, Post later menu,
   `-uiTestNotificationTap` script/cleanUp/deletedScript/invalid/duplicate). Add to `UISmoke`.
10. Docs: `NOTIFICATIONS.md` (campaigns, copy keys, eligibility, destinations, cancellation, consent, caps/priority, successful use,
    gates, background limits, scheduling/attribution semantics, disabled future campaigns, tests, device checklist); update
    `ARCHITECTURE.md`, `DESIGN_PROJECT.md` (new section), `CLAUDE.md`/`LaunchOptions` doc for the new launch arguments.
11. `scripts/test.sh fast`, `smoke`, then `full`; `scripts/check-warnings.sh`; `xcrun simctl --set testing delete all`.

Design decisions already taken (keep): Continue my projects / reminders / routine on by default but nothing is scheduled until iOS
permission, which is only asked on a reminder or a toggle; discovery & what's new off; consent for discovery also covers in-app intros;
Remote Control is in-app only; telemetry only with "Help improve Cue"; exports are never opened by a notification.
