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
    let writer: ScriptWriting
    let textRecognizer: TextRecognitionManager
    let importer: DocumentImportService
    let exporter: VideoExportService
    let photos: PhotoLibraryManager
    let thumbnails: VideoThumbnailService
    let editing: TakeEditService
    let apps: ExternalAppService

    init(options: LaunchOptions) {
        library = ScriptLibraryService(repository: options.scriptRepository)
        takes = TakeLibraryService(repository: options.takeRepository)
        preferences = PreferencesService(defaults: options.defaults)
        profile = CreatorProfileService(defaults: options.defaults)
        session = SessionService(defaults: options.defaults, checker: options.credentialChecker)
        rules = options.platformRules
        quota = UsageQuotaService(defaults: options.defaults)
        store = StoreManager()
        presentation = PresentationService()
        toast = ToastService()
        camera = CameraManager()
        audio = AudioInputManager()
        speech = SpeechRecognitionManager()
        writer = options.writer
        textRecognizer = TextRecognitionManager()
        importer = DocumentImportService()
        exporter = VideoExportService()
        photos = PhotoLibraryManager()
        thumbnails = VideoThumbnailService()
        editing = TakeEditService()
        apps = ExternalAppService()
    }

    func load() {
        library.load()
        takes.load()
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
            .environment(services.textRecognizer)
            .environment(services.importer)
            .environment(services.exporter)
            .environment(services.photos)
            .environment(services.thumbnails)
            .environment(services.editing)
            .environment(services.apps)
    }
}
