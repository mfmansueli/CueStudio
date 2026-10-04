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
    let audio: AudioInputManager
    let speech: SpeechRecognitionManager
    let dictation: DictationService
    let ideaDraft: IdeaDraftService
    let starter: ScriptStarter
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
    let remote: RemoteControlService
    let languages: LanguageService
    let personalization: PersonalizationService
    let onboarding: OnboardingService
    let milestones: MilestoneService
    let topicTagging: TopicTaggingService
    let logbook: LogbookService
    let aiStatus: AIStatus
    let appIcon: AppIconService
    let permissions: PermissionRequesting

    init(options: LaunchOptions) {
        languages = LanguageService(defaults: options.defaults, store: options.languageStore) { language in
            InterfaceLocale.current = Locale(identifier: language.interfaceLocalization)
            InterfaceDirection.apply(rightToLeft: language.isRightToLeft)
        }
        library = ScriptLibraryService(repository: options.scriptRepository)
        takes = TakeLibraryService(repository: options.takeRepository)
        preferences = PreferencesService(defaults: options.defaults)
        personalization = PersonalizationService(defaults: options.defaults)
        onboarding = OnboardingService(defaults: options.defaults, isEnabled: options.showsOnboarding)
        milestones = MilestoneService(defaults: options.defaults)
        appIcon = AppIconService(switcher: options.isInMemory ? InMemoryAppIcon() : SystemAppIcon())
        permissions = options.permissions ?? SystemPermissions()
        profile = CreatorProfileService(defaults: options.defaults)
        session = SessionService(defaults: options.defaults, checker: options.credentialChecker)
        rules = options.platformRules
        quota = UsageQuotaService(counter: options.exportCounter, defaults: options.defaults)
        store = StoreManager()
        presentation = PresentationService()
        toast = ToastService()
        camera = CameraManager()
        audio = AudioInputManager()
        speech = SpeechRecognitionManager()
        dictation = options.dictation ?? DictationService(audio: AudioInputManager(), speech: SpeechRecognitionManager(use: .dictation))
        ideaDraft = IdeaDraftService()
        starter = ScriptStarter(
            library: library, rules: rules, profile: profile, languages: languages,
            presentation: presentation, ideaDraft: ideaDraft
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
        apps = ExternalAppService(pretendsInstalled: options.appsAreInstalled)
        remote = RemoteControlService(transport: options.remoteTransport)
        logbook = LogbookService(defaults: options.defaults)
        aiStatus = AIStatus(writer: options.writer)
        topicTagging = TopicTaggingService(library: library, profile: profile, personalization: personalization, writer: writer)
    }

    func load() {
        library.load()
        takes.load()
        // A creator who already has scripts, takes or a profile skips the first flight.
        onboarding.resolve(
            hasExistingContent: !library.scripts.isEmpty || !takes.takes.isEmpty || !profile.profile.niches.isEmpty
        )
    }

    /// Lets App Intents (Siri, Shortcuts) read the same script library the app shows.
    func registerIntentDependencies() {
        let library = library
        AppDependencyManager.shared.add(dependency: library)
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
            .environment(services.textRecognizer)
            .environment(services.importer)
            .environment(services.exporter)
            .environment(services.photos)
            .environment(services.thumbnails)
            .environment(services.editing)
            .environment(services.apps)
            .environment(services.remote)
            .environment(services.languages)
            .environment(services.personalization)
            .environment(services.onboarding)
            .environment(services.milestones)
            .environment(services.appIcon)
            .environment(services.topicTagging)
            .environment(services.logbook)
            .environment(services.aiStatus)
    }
}
