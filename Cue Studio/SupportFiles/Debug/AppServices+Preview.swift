//
//  AppServices+Preview.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Shared preview services, so a preview can build a view model from the same services it
/// injects into the environment.
extension AppServices {
    /// In-memory storage with the sample scripts.
    static let preview = makePreview(seeded: true)
    /// In-memory storage, empty library (first run).
    static let previewEmpty = makePreview(seeded: false)

    private static func makePreview(seeded: Bool) -> AppServices {
        var options = LaunchOptions()
        options.scriptRepository = InMemoryScriptRepository(scripts: seeded ? SampleScripts.all : [])
        options.takeRepository = InMemoryTakeRepository(takes: seeded ? SampleTakes.all() : [])
        options.draftStore = InMemoryQuickEditDraftStore()
        options.exportCounter = InMemoryExportCountStore()
        options.defaults = UserDefaults(suiteName: "studio.cue.previews") ?? .standard
        options.platformRules = PlatformRulesService(cacheURL: nil, remoteURL: nil)
        options.remoteTransport = DemoRemoteTransport(connects: false)
        options.interfaceLanguage = InterfaceLanguageStore(persists: false)
        let services = AppServices(options: options)
        services.load()
        return services
    }
}
#endif
