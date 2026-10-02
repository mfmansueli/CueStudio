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
/// - `-uiTestDemoEdit`: "3 morning habits" Take 3 opens in the editor as the v10 design's demo
///   (`SampleEdit`).
/// - `-uiTestSampleVideo`: with the sample takes, writes small real videos behind the "3 morning
///   habits" takes, so Quick edit can play, scrub and trim them.
/// - `-uiTestRemoteConnects`: with the above, a remote "connects" right after pairing starts (UI
///   tests have no second device). Without it the remote link stays offline.
/// - `-uiTestAppearance <light|dark>`: with `-uiTestInMemory`, Cue's screens start light or dark
///   (as if picked in Settings › Appearance) whatever the simulator is set to.
/// - `-uiTestAppLanguage <lproj>`: with `-uiTestInMemory`, Cue's interface starts in that language
///   (as if picked in Language & Region) without changing the simulator's. The interface language
///   always lives in memory under `-uiTestInMemory`.
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
    var remoteTransport: RemoteTransport = NearbyRemoteTransport()
    var languageStore: AppLanguageStoring = SystemAppLanguageStore()

    static func fromProcess() -> LaunchOptions {
        var options = LaunchOptions()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestInMemory") {
            let seeded = arguments.contains("-uiTestSeedSamples")
            options.scriptRepository = InMemoryScriptRepository(scripts: seeded ? SampleScripts.all : [])
            var takes = seeded ? SampleTakes.all() : []
            // The editor's demo: "3 morning habits" Take 3 becomes the design's 21.6 s edit.
            if arguments.contains("-uiTestDemoEdit"), let index = takes.firstIndex(where: {
                $0.scriptID == SampleScripts.morningHabits.id && $0.number == 3
            }) {
                takes[index].duration = SampleEdit.duration
                takes[index].fileName = "sample-demo-edit.mov"
                takes[index].edit = SampleEdit.make(aspect: takes[index].aspect)
            }
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
            if let index = arguments.firstIndex(of: "-uiTestAppearance"), arguments.indices.contains(index + 1),
               AppAppearance(rawValue: arguments[index + 1]) != nil {
                options.defaults.set(arguments[index + 1], forKey: DefaultsKey.appAppearance)
            }
            options.platformRules = PlatformRulesService(cacheURL: nil, remoteURL: nil)
            options.remoteTransport = DemoRemoteTransport(connects: arguments.contains("-uiTestRemoteConnects"))
            let appLanguage = arguments.firstIndex(of: "-uiTestAppLanguage").flatMap { index in
                arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
            }
            options.languageStore = InMemoryAppLanguageStore(chosenLocalization: appLanguage)
            if arguments.contains("-uiTestStubAI") || arguments.contains("-uiTestNoAI") {
                options.writer = StubScriptWriter(available: !arguments.contains("-uiTestNoAI"))
            }
        }
        #endif
        return options
    }
}
