//
//  LaunchOptions.swift
//  Cue Studio
//

import Foundation

/// Storage the app starts with. Release builds always use the real stores; Debug builds accept
/// launch arguments so UI tests start from a known state:
/// - `-uiTestInMemory`: in-memory scripts and takes, and a throwaway UserDefaults suite.
/// - `-uiTestSeedSamples`: with the above, starts with the sample scripts.
/// - `-uiTestPro`: starts on Cue Pro (read by `StoreManager`).
/// - `-uiTestStubAI` / `-uiTestNoAI`: instant, predictable AI, or none at all.
struct LaunchOptions {
    var scriptRepository: ScriptRepository = LocalScriptRepository()
    var takeRepository: TakeRepository = LocalTakeRepository()
    var defaults: UserDefaults = .standard
    /// UI tests and previews swap in rules read from the bundle only (no cache, no download).
    var platformRules: PlatformRulesService = PlatformRulesService()
    var writer: ScriptWriting = ScriptAIService()

    static func fromProcess() -> LaunchOptions {
        var options = LaunchOptions()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestInMemory") {
            let seeded = arguments.contains("-uiTestSeedSamples")
            options.scriptRepository = InMemoryScriptRepository(scripts: seeded ? SampleScripts.all : [])
            options.takeRepository = InMemoryTakeRepository()
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
