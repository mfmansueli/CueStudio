//
//  AppServices.swift
//  Cue Studio
//

import SwiftUI

/// Every app-wide service, created once for the app session. `RootView` keeps it in `@State` and
/// injects each service into the environment; screens read them with `@Environment(Service.self)`.
struct AppServices {
    let library: ScriptLibraryService
    let takes: TakeLibraryService
    let preferences: PreferencesService
    let profile: CreatorProfileService
    let quota: UsageQuotaService
    let store: StoreManager
    let presentation: PresentationService
    let toast: ToastService
    let camera: CameraManager
    let audio: AudioInputManager
    let speech: SpeechRecognitionManager
    let writer: ScriptAIService
    let importer: DocumentImportService
    let exporter: VideoExportService
    let photos: PhotoLibraryManager
    let thumbnails: VideoThumbnailService

    init(options: LaunchOptions) {
        library = ScriptLibraryService(repository: options.scriptRepository)
        takes = TakeLibraryService(repository: options.takeRepository)
        preferences = PreferencesService(defaults: options.defaults)
        profile = CreatorProfileService(defaults: options.defaults)
        quota = UsageQuotaService(defaults: options.defaults)
        store = StoreManager()
        presentation = PresentationService()
        toast = ToastService()
        camera = CameraManager()
        audio = AudioInputManager()
        speech = SpeechRecognitionManager()
        writer = ScriptAIService()
        importer = DocumentImportService()
        exporter = VideoExportService()
        photos = PhotoLibraryManager()
        thumbnails = VideoThumbnailService()
    }

    func load() {
        library.load()
        takes.load()
    }
}

extension View {
    func environment(_ services: AppServices) -> some View {
        environment(services.library)
            .environment(services.takes)
            .environment(services.preferences)
            .environment(services.profile)
            .environment(services.quota)
            .environment(services.store)
            .environment(services.presentation)
            .environment(services.toast)
            .environment(services.camera)
            .environment(services.audio)
            .environment(services.speech)
            .environment(services.writer)
            .environment(services.importer)
            .environment(services.exporter)
            .environment(services.photos)
            .environment(services.thumbnails)
    }
}
