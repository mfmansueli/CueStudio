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
    let session: SessionService
    let rules: PlatformRulesService
    let quota: UsageQuotaService
    let store: StoreManager
    let presentation: PresentationService
    let toast: ToastService
    let camera: CameraManager
    /// What the recorder films with: the camera, or a stand-in under UI tests.
    let recorderCamera: any CameraControlling
    let audio: AudioInputManager
    let speech: SpeechRecognitionManager
    let dictation: DictationService
    let ideaDraft: IdeaDraftService
    let starter: ScriptStarter
    let ideaTransition: IdeaTransitionService
    /// The pause between the groups of words of a script the AI writes into the page.
    let scriptRevealPause: Duration
    let writer: ScriptWriting
    let textRecognizer: TextRecognitionManager
    let importer: DocumentImportService
    let exporter: VideoExportService
    let photos: PhotoLibraryManager
    let thumbnails: VideoThumbnailService
    let editing: TakeEditService
    let drafts: QuickEditDraftStoring
    let apps: ExternalAppService
    /// Hands an exported video to a platform (Share Kit, Instagram's hand-off, the share sheet) and says what is known.
    let sharing: VideoSharing
    /// Where a free export is counted, once per exported file.
    let ledger: ExportLedgerService
    let remote: RemoteControlService
    let languages: LanguageService
    /// What this device does in each language (interface, Apple Intelligence, speech, translation), asked once and kept.
    let capabilities: LanguageCapabilityService
    let personalization: PersonalizationService
    let onboarding: OnboardingService
    let milestones: MilestoneService
    let shareQueue: ShareQueueService
    /// The settings store (the app's, or the UI tests' in-memory one).
    let defaults: UserDefaults
    let topicTagging: TopicTaggingService
    let logbook: LogbookService
    let brands: BrandStore
    let sky: SkyMemory
    let aiStatus: AIStatus
    let voiceQuestions: VoiceQuestionScheduler
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

    init(options: LaunchOptions) {
        languages = LanguageService(defaults: options.defaults, store: options.languageStore) { language in
            InterfaceLocale.current = Locale(identifier: language.interfaceLocalization)
            InterfaceDirection.apply(rightToLeft: language.isRightToLeft)
        }
        capabilities = LanguageCapabilityService(checker: options.languageCapabilities)
        library = ScriptLibraryService(repository: options.scriptRepository)
        takes = TakeLibraryService(repository: options.takeRepository)
        preferences = PreferencesService(defaults: options.defaults)
        personalization = PersonalizationService(defaults: options.defaults)
        onboarding = OnboardingService(defaults: options.defaults, isEnabled: options.showsOnboarding, startStep: options.onboardingStep)
        milestones = MilestoneService(defaults: options.defaults)
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
        fakesShareSheet = options.fakesShareSheet
        profile = CreatorProfileService(defaults: options.defaults)
        session = SessionService(defaults: options.defaults, checker: options.credentialChecker)
        rules = options.platformRules
        quota = UsageQuotaService(
            counter: options.exportCounter, defaults: options.defaults, resetsOnNewInstall: options.resetsExportsOnNewInstall
        )
        store = StoreManager()
        ledger = ExportLedgerService(store: options.exportLedger, quota: quota)
        presentation = PresentationService()
        toast = ToastService()
        let realCamera = CameraManager()
        camera = realCamera
        recorderCamera = options.recorderCamera ?? realCamera
        audio = AudioInputManager()
        speech = SpeechRecognitionManager()
        dictation = options.dictation ?? DictationService(audio: AudioInputManager(), speech: SpeechRecognitionManager(use: .dictation))
        ideaDraft = IdeaDraftService()
        let sky = SkyMemory(defaults: options.defaults)
        let ideaTransition = IdeaTransitionService()
        // UI tests don't wait three seconds for every idea (`-uiTestStarTransition` brings the real timings back).
        if options.isInMemory, !options.keepsStarTransitionTimings { ideaTransition.speed = 0.05 }
        self.ideaTransition = ideaTransition
        starter = ScriptStarter(
            library: library, rules: rules, profile: profile, languages: languages,
            presentation: presentation, ideaDraft: ideaDraft, transition: ideaTransition, sky: sky,
            writer: options.writer, toast: toast
        )
        writer = options.writer
        scriptRevealPause = options.scriptRevealPause
        textRecognizer = TextRecognitionManager()
        importer = DocumentImportService()
        exporter = VideoExportService()
        photos = PhotoLibraryManager()
        thumbnails = VideoThumbnailService()
        editing = TakeEditService()
        drafts = options.draftStore
        let apps = ExternalAppService()
        self.apps = apps
        sharing = options.sharing ?? VideoSharingService(apps: apps, tikTok: TikTokShareManager(), instagram: InstagramShareManager(apps: apps))
        remote = RemoteControlService(transport: options.remoteTransport)
        logbook = LogbookService(defaults: options.defaults)
        brands = BrandStore(repository: options.brandRepository)
        self.sky = sky
        aiStatus = AIStatus(writer: options.writer)
        privacy = PrivacyPreferencesService(defaults: options.defaults, writer: options.writer)
        voiceQuestions = VoiceQuestionScheduler(profile: profile, defaults: options.defaults, skipsGates: options.voiceTipSkipsGates)
        eraser = DataEraserService(
            library: library, takes: takes, drafts: options.draftStore, logbook: logbook, brands: brands, sky: sky,
            profile: profile, preferences: preferences, defaults: options.defaults
        )
        topicTagging = TopicTaggingService(library: library, profile: profile, personalization: personalization, writer: writer)
    }

    func load() {
        library.load()
        takes.load()
        brands.load()
        // A creator who already has scripts, takes or a profile skips the first flight.
        onboarding.resolve(
            hasExistingContent: !library.scripts.isEmpty || !takes.takes.isEmpty || !profile.profile.niches.isEmpty
        )
    }

    /// Lets App Intents (Siri, Shortcuts) read the same script library the app shows, and save ideas in the same Logbook.
    func registerIntentDependencies() {
        let library = library
        AppDependencyManager.shared.add(dependency: library)
        let logbook = logbook
        AppDependencyManager.shared.add(dependency: logbook)
    }
}

extension View {
    func environment(_ services: AppServices) -> some View {
        environment(services.library)
            .environment(services.takes)
            .environment(services.preferences)
            .environment(services.profile)
            .environment(services.session)
            .environment(services.rules)
            .environment(services.quota)
            .environment(services.store)
            .environment(services.presentation)
            .environment(services.toast)
            .environment(services.camera)
            .environment(services.audio)
            .environment(services.speech)
            .environment(services.dictation)
            .environment(services.ideaDraft)
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
            .environment(services.shareQueue)
            .environment(services.appIcon)
            .environment(services.topicTagging)
            .environment(services.logbook)
            .environment(services.brands)
            .environment(services.sky)
            .environment(services.aiStatus)
            .environment(services.voiceQuestions)
            .environment(services.eraser)
            .environment(services.privacy)
            .environment(services.permissionStatus)
            .environment(\.proOpeningFrozenAt, services.proFrozenTime)
            .environment(\.onboardingChapterFrozenAt, services.chapterFrozenTime)
            .environment(\.sendOffFrozenAt, services.sendOffFrozenTime)
            .environment(\.storyFrozenAt, services.storyFrozenTime)
            .environment(\.fakesShareSheet, services.fakesShareSheet)
    }
}
