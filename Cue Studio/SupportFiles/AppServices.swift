//
//  AppServices.swift
//  Cue Studio
//

import AppIntents
import SwiftUI

/// Every app-wide service, created once for the app session. `CueStudioApp` keeps it in `@State`,
/// `RootView` injects each service into the environment, and screens read them with
/// `@Environment(Service.self)`.
struct AppServices {
    let library: ScriptLibraryService
    let takes: TakeLibraryService
    let preferences: PreferencesService
    let profile: CreatorProfileService
    let rules: PlatformRulesService
    let quota: UsageQuotaService
    let store: StoreManager
    let presentation: PresentationService
    let toast: ToastService
    /// The editor's teaching notes already read (`PanelNote(teaches:)`).
    let panelNotes: PanelNoteMemory
    let camera: CameraManager
    /// What the recorder films with: the camera, or a stand-in under UI tests.
    let recorderCamera: any CameraControlling
    let audio: AudioInputManager
    /// My words: the creator's names and terms, which every recognizer listens for (captions, Voice Following, dictation).
    let myWords: MyWordsStoring
    let speech: SpeechRecognitionManager
    /// What the prompter's Voice Following listens through: `speech`, or a scripted one in UI tests.
    let prompterSpeech: SpeechTranscribing
    let dictation: DictationService
    let ideaDraft: IdeaDraftService
    let ideaSuggestions: IdeaSuggestionService
    let starter: ScriptStarter
    let ideaTransition: IdeaTransitionService
    /// The pause between the groups of words of a script the AI writes into the page.
    let scriptRevealPause: Duration
    let writer: ScriptWriting
    /// AI Scripts Ultra (Anthropic's Claude, through Cue's server), written only when the creator chose it and allowed it; unavailable in Release.
    let ultra: UltraScriptService
    /// Reads what the creator imports for how they sound (Import my writing), with the model on this iPhone.
    let styleReader: any WritingStyleReading
    let textRecognizer: TextRecognitionManager
    let importer: DocumentImportService
    let exporter: VideoExportService
    /// What the review exports with: the exporter, slowed down in UI tests that look at the progress.
    let reviewExporter: VideoExporting
    /// Exports that go on when the creator leaves Cue (iOS's continued tasks, with the GPU); none in UI tests and previews.
    let backgroundExports: BackgroundExportRunner
    let photos: PhotoLibraryManager
    let thumbnails: VideoThumbnailService
    let editing: TakeEditService
    /// Analyzes the recordings' motion (faces, bodies, shake) for Follow face and Stabilize, while Cue is open and cool.
    let motion: MotionAnalysisService
    let drafts: QuickEditDraftStoring
    let apps: ExternalAppService
    /// Hands an exported video to a platform (Share Kit, Instagram's hand-off, the share sheet) and says what is known.
    let sharing: VideoSharing
    /// Where a free export is counted, once per exported file.
    let ledger: ExportLedgerService
    /// Invites: the creator's code, friends' first exports and what they earned (DESIGN_PROJECT §60).
    let referral: ReferralService
    /// When Cue may ask for an App Store rating (`ReviewPromptPolicy`).
    let reviewPrompt: ReviewPromptService
    let remote: RemoteControlService
    /// The Apple Watch companion: records and drives the recorder from the wrist.
    let watch: WatchLinkService
    let languages: LanguageService
    /// What this device does in each language (interface, Apple Intelligence, speech, translation), asked once and kept.
    let capabilities: LanguageCapabilityService
    let personalization: PersonalizationService
    let onboarding: OnboardingService
    let milestones: MilestoneService
    /// The guide from the first script to the first video shared.
    let voyage: FirstVoyageService
    /// What Cue suggests on its own, one at a time (`GuidanceGate`).
    let guidance: GuidanceGate
    /// Cue's drafts, and what the creator made of them once recorded.
    let draftLearning: DraftLearningService
    let shareQueue: ShareQueueService
    /// The settings store (the app's, or the UI tests' in-memory one).
    let defaults: UserDefaults
    let topicTagging: TopicTaggingService
    let logbook: LogbookService
    let brands: BrandStore
    /// The creator's imported font families, registered for Cue at launch.
    let fonts: CustomFontStore
    /// The script libraries' downloaded files (`FontPackStore`).
    let fontPacks: FontPackStore
    /// Photos, videos and logos kept to reuse in any video.
    let mediaLibrary: MediaLibraryStore
    let brandKits: BrandKitStore
    let aiStatus: AIStatus
    let voiceQuestions: VoiceQuestionScheduler
    /// Reminders, the routine, project nudges and the tools' introductions (local notifications only).
    let notifications: NotificationService
    let eraser: DataEraserService
    let privacy: PrivacyPreferencesService
    let appIcon: AppIconService
    let permissions: PermissionRequesting
    let permissionStatus: PermissionsService
    /// The welcome's star opening plays, except in UI tests that don't ask for it.
    let playsWelcomeOpening: Bool
    /// UI tests: the opening stands still at this second.
    let welcomeFrozenTime: Double?
    /// UI tests: the Pro opening stands still at this second.
    let proFrozenTime: Double?
    /// UI tests: the chapter of the first flight on screen stands still at this second of its opening.
    let chapterFrozenTime: Double?
    /// UI tests: the last topic of 1.2 stands still at this age of its birth.
    let topicBirthFrozenAge: Double?
    /// UI tests: on 1.3 TikTok is picked and the light of the pick stands still at this age.
    let platformPickFrozenAge: Double?
    /// UI tests: the send-off stands still at this second.
    let sendOffFrozenTime: Double?
    /// UI tests: the review opens on the first-star / milestone story.
    let showsFirstStar: Bool
    let storyFrozenTime: Double?
    let milestoneToShow: Int?
    /// UI tests: a stand-in for the system share sheet.
    let fakesShareSheet: Bool
    /// UI tests: the editor reads Low Power Mode as on.
    let forcesLowPowerMode: Bool
    /// UI tests: a white or black frame in place of the editor's video.
    let previewStandInFrame: PreviewStandInFrame?
    let logsDockMotion: Bool

    init(options: LaunchOptions) {
        languages = LanguageService(defaults: options.defaults, store: options.languageStore) { language in
            InterfaceLocale.current = Locale(identifier: language.interfaceLocalization)
            InterfaceDirection.apply(rightToLeft: language.isRightToLeft)
        }
        capabilities = LanguageCapabilityService(checker: options.languageCapabilities)
        library = ScriptLibraryService(repository: options.scriptRepository)
        takes = TakeLibraryService(
            repository: options.takeRepository, drafts: options.draftStore,
            pendingDeletions: options.isInMemory ? nil : PendingTakeDeletions(defaults: options.defaults)
        )
        preferences = PreferencesService(defaults: options.defaults)
        personalization = PersonalizationService(defaults: options.defaults)
        onboarding = OnboardingService(defaults: options.defaults, isEnabled: options.showsOnboarding, startStep: options.onboardingStep)
        milestones = MilestoneService(defaults: options.defaults)
        voyage = FirstVoyageService(
            library: library, takes: takes, milestones: milestones, defaults: options.defaults,
            isEnabled: !options.isInMemory || options.showsVoyage
        )
        guidance = GuidanceGate()
        shareQueue = ShareQueueService(defaults: options.defaults)
        defaults = options.defaults
        let iconSwitcher: any AppIconSwitching = options.isInMemory ? InMemoryAppIcon() : SystemAppIcon()
        appIcon = AppIconService(switcher: iconSwitcher)
        let permissions = options.permissions ?? SystemPermissions()
        self.permissions = permissions
        permissionStatus = PermissionsService(permissions: permissions)
        playsWelcomeOpening = !options.isInMemory || options.keepsWelcomeOpening
        welcomeFrozenTime = options.welcomeFrozenTime
        proFrozenTime = options.proFrozenTime
        chapterFrozenTime = options.chapterFrozenTime
        topicBirthFrozenAge = options.topicBirthFrozenAge
        platformPickFrozenAge = options.platformPickFrozenAge
        sendOffFrozenTime = options.sendOffFrozenTime
        showsFirstStar = options.showsFirstStar
        storyFrozenTime = options.storyFrozenTime
        milestoneToShow = options.milestoneToShow
        // What UI tests stand in for: the share sheet, Low Power Mode, the editor's video.
        (fakesShareSheet, forcesLowPowerMode, previewStandInFrame) = (options.fakesShareSheet, options.forcesLowPowerMode, options.previewStandInFrame)
        logsDockMotion = options.logsDockMotion
        profile = CreatorProfileService(defaults: options.defaults)
        // Sign in with Apple is gone (owner, 09/11/2026): what it kept goes, the profile's name stays (`AppleSignInLeftovers`).
        AppleSignInLeftovers.erase(from: options.defaults)
        rules = options.platformRules
        quota = UsageQuotaService(
            counter: options.exportCounter, defaults: options.defaults, resetsOnNewInstall: options.resetsExportsOnNewInstall
        )
        store = StoreManager()
        ledger = ExportLedgerService(store: options.exportLedger, quota: quota)
        presentation = PresentationService()
        toast = ToastService()
        panelNotes = PanelNoteMemory(defaults: options.defaults)
        let realCamera = CameraManager()
        camera = realCamera
        recorderCamera = options.recorderCamera ?? realCamera
        audio = AudioInputManager()
        myWords = MyWordsStore(defaults: options.defaults)
        speech = SpeechRecognitionManager(myWords: myWords)
        prompterSpeech = options.prompterSpeech ?? speech
        dictation = options.dictation ?? DictationService(audio: AudioInputManager(), speech: SpeechRecognitionManager(use: .dictation, myWords: myWords))
        ideaDraft = IdeaDraftService(defaults: options.defaults)
        let ideaTransition = IdeaTransitionService()
        // UI tests don't wait three seconds for every idea (`-uiTestStarTransition` brings the real timings back).
        if options.isInMemory, !options.keepsStarTransitionTimings { ideaTransition.speed = 0.05 }
        self.ideaTransition = ideaTransition
        // The free scripts and Pro's monthly ones: this iPhone's count, replaced by Cue's server's while it enforces one (`UltraAllowanceService`).
        let ultra = UltraScriptService(
            isAvailable: options.ultraAvailable, checksDistribution: options.checksUltraDistribution,
            consent: UltraConsentService(defaults: options.defaults), budget: UltraCallBudget(defaults: options.ultraBudgetDefaults),
            allowance: UltraAllowanceService(defaults: options.defaults) { [store] in
                UltraAllowance.Membership(tier: store.tier)
            },
            invite: UltraInviteService(defaults: options.defaults), spend: UltraSpendLedger(defaults: options.ultraBudgetDefaults),
            makeClient: options.makeUltraClient
        )
        self.ultra = ultra
        referral = Self.makeReferral(options: options, quota: quota, milestones: milestones, store: store, ultra: ultra, toast: toast)
        reviewPrompt = ReviewPromptService(defaults: options.defaults) { [quota, store] in quota.exportsLeft(for: store.tier) }
        starter = ScriptStarter(
            library: library, profile: profile, languages: languages,
            presentation: presentation, ideaDraft: ideaDraft, transition: ideaTransition,
            writer: options.writer, ultra: ultra, toast: toast
        )
        writer = options.writer
        let busyWriter = options.writer
        styleReader = options.styleReader ?? AppleWritingStyleReader(isBusy: { busyWriter.isBusyForeground }, isEnabled: { busyWriter.isEnabled })
        scriptRevealPause = options.scriptRevealPause
        textRecognizer = TextRecognitionManager()
        importer = DocumentImportService()
        // The UI tests' in-memory runs never reach the network for fonts.
        fontPacks = options.assetRoot.map { root in
            FontPackStore(source: OfflineFontPackSource(), directory: root.appending(path: "FontPacks", directoryHint: .isDirectory))
        } ?? FontPackStore()
        exporter = VideoExportService(fontPacks: fontPacks)
        #if DEBUG
        reviewExporter = options.slowExports ? SlowVideoExporter(inner: exporter) : exporter
        #else
        reviewExporter = exporter
        #endif
        backgroundExports = BackgroundExportRunner(scheduler: options.usesContinuedTasks ? SystemContinuedTaskScheduler() : nil)
        photos = PhotoLibraryManager()
        thumbnails = VideoThumbnailService()
        editing = TakeEditService(myWords: myWords)
        motion = MotionAnalysisService()
        drafts = options.draftStore
        let apps = ExternalAppService()
        self.apps = apps
        sharing = options.sharing ?? VideoSharingService(apps: apps, tikTok: TikTokShareManager(), instagram: InstagramShareManager(apps: apps))
        remote = RemoteControlService(transport: options.remoteTransport)
        watch = WatchLinkService(transport: options.watchTransport)
        logbook = LogbookService(defaults: options.defaults)
        ideaSuggestions = IdeaSuggestionService(
            writer: options.writer, profile: profile, interfaceLanguage: { [languages] in languages.interfaceLanguage },
            inspiration: { [library, logbook] in IdeaInspiration.recent(scripts: library.scripts, notes: logbook.waiting) },
            notes: { [logbook] in logbook.waiting },
            signals: { [milestones, takes, library] in
                IdeaSignals.read(records: milestones.records, takes: takes.takes, scripts: library.scripts)
            },
            region: { [isInMemory = options.isInMemory, testRegion = options.occasionsRegion] in
                isInMemory ? testRegion : Locale.current.region?.identifier
            },
            now: { [testToday = options.occasionsToday] in testToday ?? .now },
            defaults: options.defaults
        )
        starter.briefWritten = { [ideaSuggestions] brief in ideaSuggestions.generated(from: brief) }
        starter.keepsComment = { [logbook] comment in logbook.keep(comment) }
        starter.commentAnswered = { [logbook] kept, scriptID in logbook.answered(kept, as: scriptID) }
        brands = BrandStore(repository: options.brandRepository)
        let fontFolder = options.assetRoot?.appending(path: "Fonts", directoryHint: .isDirectory) ?? CustomFontFiles.directory
        fonts = CustomFontStore(repository: LocalCustomFontRepository(directory: fontFolder), directory: fontFolder)
        let libraryFolder = options.assetRoot?.appending(path: "MediaLibrary", directoryHint: .isDirectory) ?? MediaLibraryFiles.directory
        mediaLibrary = MediaLibraryStore(repository: LocalMediaLibraryRepository(directory: libraryFolder), directory: libraryFolder)
        let kitFolder = options.assetRoot?.appending(path: "BrandKits", directoryHint: .isDirectory) ?? BrandKitFiles.directory
        brandKits = BrandKitStore(repository: LocalBrandKitRepository(directory: kitFolder), directory: kitFolder)
        aiStatus = AIStatus(writer: options.writer)
        privacy = PrivacyPreferencesService(defaults: options.defaults, writer: options.writer)
        draftLearning = DraftLearningService(profile: profile, toast: toast, defaults: options.defaults)
        takes.onTakeAdded = { [draftLearning] take in draftLearning.tookTake(of: take.scriptReference) }
        Self.reportWhenHelpingImprove(privacy: privacy, voyage: voyage, profile: profile, referral: referral, reviewPrompt: reviewPrompt)
        Self.wireExports(ledger: ledger, takes: takes, shareQueue: shareQueue, referral: referral, reviewPrompt: reviewPrompt)
        voiceQuestions = VoiceQuestionScheduler(profile: profile, defaults: options.defaults, skipsGates: options.voiceTipSkipsGates,
                                                invitesOnSend: options.invitesVoiceOnSend,
                                                scriptLanguage: { [languages] in (languages.scriptLanguage ?? languages.interfaceLanguage).rawValue })
        notifications = Self.makeNotifications(options: options, services: NotificationWiring(
            library: library, takes: takes, shareQueue: shareQueue, logbook: logbook, ideas: ideaSuggestions, profile: profile,
            preferences: preferences, capabilities: capabilities, languages: languages, milestones: milestones, writer: options.writer,
            privacy: privacy, voiceQuestions: voiceQuestions, presentation: presentation, remote: remote, transition: ideaTransition
        ))
        eraser = DataEraserService(
            library: library, takes: takes, drafts: options.draftStore, logbook: logbook, brands: brands,
            profile: profile, preferences: preferences, defaults: options.defaults, notifications: notifications, voyage: voyage,
            draftLearning: draftLearning, voiceQuestions: voiceQuestions, ledger: ledger, shareQueue: shareQueue, ideas: ideaSuggestions,
            fonts: fonts, fontPacks: fontPacks, mediaLibrary: mediaLibrary, brandKits: brandKits, ideaDraft: ideaDraft,
            ultraConsent: ultra.consent, telemetry: FirebaseTelemetry()
        )
        topicTagging = TopicTaggingService(library: library, profile: profile, personalization: personalization, writer: writer)
    }

    func load() {
        library.load()
        takes.load()
        brands.load()
        // Before anything draws words: the imported fonts are registered for Cue.
        fonts.load()
        // The script libraries' files kept from before (nothing downloads here), and which script Chinese characters are
        // read in, from the creator's languages.
        fontPacks.load()
        FontPackRegistry.shared.hanReading = WritingScript.hanReading(for: [languages.scriptLanguage, languages.interfaceLanguage].compactMap(\.self))
        mediaLibrary.load()
        brandKits.load()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestSeedLibrary") {
            Task { [mediaLibrary] in await DebugLibrarySeed.seed(into: mediaLibrary) }
        }
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-uiTestImportedFont"), arguments.indices.contains(index + 1) {
            Task { [fonts] in await DebugFontSeed.seed(arguments[index + 1], into: fonts) }
        }
        #endif
        // A creator who already has scripts, takes or a profile skips the first flight.
        onboarding.resolve(
            hasExistingContent: !library.scripts.isEmpty || !takes.takes.isEmpty || !profile.profile.niches.isEmpty
        )
    }

    /// Cue in front again: what couldn't be read at launch (Cue woke in the background while the iPhone was locked) is read
    /// now, so the creator sees their libraries, what they make is saved, and the free exports are counted from the real number.
    func reloadWhatCouldntBeRead() {
        library.reloadIfUnread()
        takes.reloadIfUnread()
        brands.reloadIfUnread()
        quota.reloadIfUnread()
        fonts.reloadIfUnread()
        mediaLibrary.reloadIfUnread()
        brandKits.reloadIfUnread()
        // And writes what a failed save (a full iPhone) left only in memory, now that space may be free.
        library.saveAgainIfFailed()
        takes.saveAgainIfFailed()
    }

    /// Scripts or takes changed but couldn't be written: kept in memory, lost if Cue is closed before a save works.
    var hasUnsavedWork: Bool { library.saveFailed || takes.saveFailed }

    /// Gives back the space past sessions' sound files take (`EditStorageCleaner`), a few seconds after launch so it never
    /// competes with it, off the main actor. The edits' media go only when nothing Cue keeps names them and they haven't
    /// changed for a week (`EditStorageCleaner.orphanedMedia`). In Debug, what UI tests left goes too (`UITestLeftovers`).
    func cleanUpStorage() {
        let launchedAt = Date()
        let libraryFolder = mediaLibrary.directory
        let kitFolder = brandKits.directory
        Task.detached(priority: .background) {
            try? await Task.sleep(for: .seconds(8))
            await EditStorageCleaner.clean(launchedAt: launchedAt)
            #if DEBUG
            await UITestLeftovers.removeAll()
            #endif
            // What the creator removed from the library or the kits, past its session's Undo (`LibraryFileSweep`).
            LibraryFileSweep.sweep(libraryFolder, listName: "library.json", launchedAt: launchedAt)
            LibraryFileSweep.sweep(kitFolder, listName: "kits.json", launchedAt: launchedAt)
        }
        // A removed font's files, once nothing names it any more.
        Task { [fonts, defaults] in
            try? await Task.sleep(for: .seconds(12))
            await fonts.sweepRemoved(defaults: defaults)
        }
        // A take a past session never filed (Cue stopped mid-take, or the library couldn't take it in) comes back (`TakeRecovery`); then,
        // well after launch, the take videos nothing names go once their week is up, and deletions iOS cut short finish (`TakeOrphanSweep`).
        Task { [takes, preferences, library, defaults] in
            try? await Task.sleep(for: .seconds(3))
            await TakeRecovery.recover(
                into: takes, camera: preferences.camera, launchedAt: launchedAt, script: { library.script(id: $0) }
            )
            try? await Task.sleep(for: .seconds(12))
            await TakeOrphanSweep.sweep(takes: takes, pending: PendingTakeDeletions(defaults: defaults))
        }
    }

    /// What a notification opens is checked against the app's own objects; and a tap that launched Cue (or a UI test's) waits for the UI.
    func connectNotifications(tap scenario: String?) {
        let services = self
        notifications.isAlive = { NotificationNavigator(services: services).exists($0) }
        NotificationRouter.shared.foreground = { [notifications] payload, _ in notifications.foregroundPresentation(for: payload) }
        #if DEBUG
        if let scenario {
            for interaction in DebugNotificationTaps.interactions(for: scenario, services: self) { NotificationRouter.shared.receive(interaction) }
        }
        #endif
    }

    /// Lets App Intents (Siri, Shortcuts) read the same script library the app shows, and save ideas in the same Logbook.
    func registerIntentDependencies() {
        let library = library
        AppDependencyManager.shared.add(dependency: library)
        let logbook = logbook
        AppDependencyManager.shared.add(dependency: logbook)
    }
}

extension AppServices {
    /// What the notifications are built from (one argument, so the list stays readable).
    struct NotificationWiring {
        let library: ScriptLibraryService
        let takes: TakeLibraryService
        let shareQueue: ShareQueueService
        let logbook: LogbookService
        let ideas: IdeaSuggestionService
        let profile: CreatorProfileService
        let preferences: PreferencesService
        let capabilities: LanguageCapabilityService
        let languages: LanguageService
        let milestones: MilestoneService
        let writer: ScriptWriting
        let privacy: PrivacyPreferencesService
        let voiceQuestions: VoiceQuestionScheduler
        let presentation: PresentationService
        let remote: RemoteControlService
        let transition: IdeaTransitionService
    }

    /// What only "Help improve Cue" sends: the first voyage's tips and the "+ Something else" counts of My Cue Voice (B14), never text.
    private static func reportWhenHelpingImprove(
        privacy: PrivacyPreferencesService, voyage: FirstVoyageService, profile: CreatorProfileService, referral: ReferralService,
        reviewPrompt: ReviewPromptService
    ) {
        voyage.report = { [privacy] event in
            if privacy.helpsImproveCue { TelemetryManager.record(event) }
        }
        profile.reportTypedAnswer = { [privacy] event in
            if privacy.helpsImproveCue { TelemetryManager.record(event) }
        }
        referral.report = { [privacy] event in
            if privacy.helpsImproveCue { TelemetryManager.record(event) }
        }
        reviewPrompt.report = { [privacy] in
            if privacy.helpsImproveCue { TelemetryManager.record(ReferralTelemetryEvent(step: .reviewAsked)) }
        }
    }

    /// What the export ledger tells the rest of Cue.
    private static func wireExports(
        ledger: ExportLedgerService, takes: TakeLibraryService, shareQueue: ShareQueueService, referral: ReferralService,
        reviewPrompt: ReviewPromptService
    ) {
        // A deleted take leaves nothing behind: its exported videos waiting in tmp, their records, and a "Continue posting" for a video that
        // is gone.
        takes.takeGone = { [ledger, shareQueue] take in
            ledger.forget(takeID: take.id)
            shareQueue.discard(takeID: take.id)
        }
        // A video left Cue for the first time: a friend's invite counts (§60), and a later one may ask for a rating.
        ledger.firstDelivered = { [referral, reviewPrompt] in
            reviewPrompt.delivered()
            Task { await referral.exportDelivered() }
        }
    }

    /// The invites (§60): the server's count turned into exports on the free plan and Ultra AI scripts on Pro, said with a toast.
    private static func makeReferral(
        options: LaunchOptions, quota: UsageQuotaService, milestones: MilestoneService, store: StoreManager, ultra: UltraScriptService,
        toast: ToastService
    ) -> ReferralService {
        let referral = ReferralService(
            store: options.referralStore, client: options.makeReferralClient(),
            hasExported: { [quota, milestones] in quota.exportsUsed > 0 || !milestones.records.isEmpty },
            isPro: { [store] in store.tier.isPro }, ultraOffered: { [ultra] in ultra.isAvailable },
            proof: { [store] in await store.proProof() },
            apply: { [quota, ultra] rewards in
                quota.bonusExports = rewards.bonusExports
                ultra.allowance?.bonusScripts = rewards.bonusUltraScripts
            },
            announce: { [toast] message in toast.show(message) }
        )
        // Ultra AI's calls name the same install, so the server counts the scripts invites earned and those written together (§57).
        ultra.callerSource = UltraCallerSource(
            installID: { [referral] in referral.installIdentity() },
            proof: { [store] in store.tier.isPro ? await store.proProof() : nil }
        )
        return referral
    }

    private static func makeNotifications(options: LaunchOptions, services wiring: NotificationWiring) -> NotificationService {
        let (milestones, takes, library, writer) = (wiring.milestones, wiring.takes, wiring.library, wiring.writer)
        let facts = AppNotificationFacts(sources: AppNotificationFacts.Sources(
            library: library, takes: takes, drafts: options.draftStore, shareQueue: wiring.shareQueue, logbook: wiring.logbook,
            ideas: wiring.ideas, profile: wiring.profile, preferences: wiring.preferences, capabilities: wiring.capabilities,
            languages: wiring.languages, milestones: milestones,
            aiWriting: { writer.isLanguageModelAvailable },
            yearReview: {
                // The universe's own rules: the review row unlocked and the story ready (December onwards).
                let videos = UniverseVideo.resolve(
                    records: milestones.records, takes: takes.takes, scripts: library.scripts, fallbackDate: milestones.firstShareDate ?? .now
                )
                let row = UniverseContent(videos: videos, topics: []).review
                return !row.isLocked && UniverseYears.storyIsReady(year: row.year) ? row.year : nil
            },
            backgrounds: { await BackgroundSupport.canFindPeople() }
        ))
        let notifications = NotificationService(
            center: options.notificationCenter ?? SystemNotificationCenter(), store: NotificationStateStore(defaults: options.defaults), facts: facts
        )
        notifications.invitesEnabled = options.notificationInvites
        notifications.sessionIntrosEnabled = options.sessionIntros
        let (languages, privacy, voiceQuestions) = (wiring.languages, wiring.privacy, wiring.voiceQuestions)
        let (presentation, remote, transition) = (wiring.presentation, wiring.remote, wiring.transition)
        notifications.interfaceLanguage = { languages.interfaceLanguage.rawValue }
        notifications.sendsUsage = { privacy.helpsImproveCue }
        notifications.tipDays = { voiceQuestions.state.shownDates }
        notifications.isForegroundBusy = {
            presentation.prompter != nil || presentation.showsRemoteController || remote.state.isConnected || transition.phase != .idle
        }
        // Both ways: a tool introduced or the invitation shown today puts the tip off, and a tip's day puts them off (`tipDays`).
        voiceQuestions.otherIntroductionToday = { notifications.introducedToday || notifications.invitedToday }
        voiceQuestions.onTipShown = { notifications.setNeedsReconcile() }
        return notifications
    }
}

extension View {
    func environment(_ services: AppServices) -> some View {
        environment(services.library)
            .environment(services.takes)
            .environment(services.ledger)
            .environment(services.preferences)
            .environment(services.profile)
            .environment(services.rules)
            .environment(services.quota)
            .environment(services.store)
            .environment(services.presentation)
            .environment(services.toast)
            .environment(services.panelNotes)
            .environment(services.camera)
            .environment(services.audio)
            .environment(services.speech)
            .environment(services.dictation)
            .environment(services.ideaDraft)
            .environment(services.ideaSuggestions)
            .environment(services.starter)
            .environment(services.ideaTransition)
            .environment(services.textRecognizer)
            .environment(services.importer)
            .environment(services.exporter)
            .environment(services.photos)
            .environment(services.thumbnails)
            .environment(services.editing)
            .environment(services.apps)
            .environment(services.remote)
            .environment(services.languages)
            .environment(services.capabilities)
            .environment(services.personalization)
            .environment(services.onboarding)
            .environment(services.milestones)
            .environment(services.voyage)
            .environment(services.guidance)
            .environment(services.draftLearning)
            .environment(services.shareQueue)
            .environment(services.appIcon)
            .environment(services.topicTagging)
            .environment(services.logbook)
            .environment(services.brands)
            .environment(services.aiStatus)
            .environment(services.voiceQuestions)
            .environment(services.notifications)
            .environment(services.eraser)
            .environment(services.privacy)
            .environment(services.ultra)
            .environment(services.referral)
            .environment(services.reviewPrompt)
            .environment(services.permissionStatus)
            .environment(\.styleReader, services.styleReader)
            .environment(\.proOpeningFrozenAt, services.proFrozenTime)
            .environment(\.onboardingChapterFrozenAt, services.chapterFrozenTime)
            .environment(\.sendOffFrozenAt, services.sendOffFrozenTime)
            .environment(\.storyFrozenAt, services.storyFrozenTime)
            .environment(\.fakesShareSheet, services.fakesShareSheet)
            .environment(\.forcesLowPowerMode, services.forcesLowPowerMode)
            .environment(\.previewStandInFrame, services.previewStandInFrame)
            .environment(\.logsDockMotion, services.logsDockMotion)
    }
}
