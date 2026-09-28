//
//  LaunchOptions.swift
//  Cue Studio
//

import Foundation

/// Storage the app starts with. Release builds always use the real stores; Debug builds accept
/// launch arguments so UI tests start from a known state:
/// - `-uiTestInMemory`: in-memory scripts, takes and export count, and a throwaway UserDefaults
///   suite.
/// - `-uiTestSeedSamples`: with the above, starts with the sample scripts and takes.
/// - `-uiTestPro`: starts on Cue Pro (read by `StoreManager`).
/// - `-uiTestStubAI` / `-uiTestNoAI`: instant, predictable AI, or none at all.
/// - `-uiTestSampleVideo`: with the sample takes, writes small real videos behind the "3 morning
///   habits" takes, so Quick edit can play, scrub and trim them.
struct LaunchOptions {
    var scriptRepository: ScriptRepository = LocalScriptRepository()
    var takeRepository: TakeRepository = LocalTakeRepository()
    var draftStore: QuickEditDraftStoring = QuickEditDraftStore()
    var exportCounter: ExportCountStoring = KeychainExportCountStore()
    var defaults: UserDefaults = .standard
    /// UI tests and previews swap in rules read from the bundle only (no cache, no download).
    var platformRules: PlatformRulesService = PlatformRulesService()
    var writer: ScriptWriting = ScriptAIService()
    var credentialChecker: AppleIDCredentialChecking = AppleIDCredentialChecker()

    static func fromProcess() -> LaunchOptions {
        var options = LaunchOptions()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestInMemory") {
            let seeded = arguments.contains("-uiTestSeedSamples")
            options.scriptRepository = InMemoryScriptRepository(scripts: seeded ? SampleScripts.all : [])
            let takes = seeded ? SampleTakes.all() : []
            let repository = InMemoryTakeRepository(takes: takes)
            options.takeRepository = repository
            options.draftStore = InMemoryQuickEditDraftStore()
            options.exportCounter = InMemoryExportCountStore()
            // Videos written by an earlier launch stay in the temporary folder: without the flag
            // they go, so every launch starts from the state it asked for.
            let habits = takes.filter { $0.scriptID == SampleScripts.morningHabits.id }
            if arguments.contains("-uiTestSampleVideo") {
                SampleVideo.writeMissing(for: habits, in: repository)
            } else {
                SampleVideo.remove(for: habits, in: repository)
            }
            let suite = "studio.cue.uitests"
            UserDefaults().removePersistentDomain(forName: suite)
            options.defaults = UserDefaults(suiteName: suite) ?? .standard
            options.platformRules = PlatformRulesService(cacheURL: nil, remoteURL: nil)
            if arguments.contains("-uiTestStubAI") || arguments.contains("-uiTestNoAI") {
                options.writer = StubScriptWriter(available: !arguments.contains("-uiTestNoAI"))
            }
        }
        #endif
        return options
    }
}
