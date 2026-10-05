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
/// - `-uiTestDemoCamera`: the recorder's camera records with no hardware (a small real video per take), for the Simulator.
/// - `-uiTestAppsInstalled`: with the above, the platforms' apps count as installed and take the video (`DemoVideoSharing`:
///   the send-off after "Share to").
/// - `-uiTestSky <off|calm|lively>`: with the above, the sky starts like that (off otherwise: an endless animation
///   keeps UI tests from finding the app idle).
/// - `-uiTestRemoteConnects`: with the above, a remote "connects" right after pairing starts (UI
///   tests have no second device). Without it the remote link stays offline.
/// - `-uiTestDictation <speech|denied|unavailable|silence>`: dictation without a microphone or a
///   model (the simulator has neither): it hears `-uiTestDictationText <words>` a word at a time
///   (`speech`), or is refused the microphone, can't recognize the language, or hears nothing.
/// - `-uiTestOnboarding`: with the above, the first flight shows (it is off in UI tests otherwise).
/// - `-uiTestPermissions <granted|denied>`: the first flight's permission prompts are answered at once.
/// - `-uiTestVoiceTip`: the My Cue Voice tip needs no second day, script, wait or cap (tests of the tip itself); without it the
///   tip stays away in UI tests (they open the app on one day).
/// - `-uiTestStarTransition`: the idea's star transition keeps its real timings (3 s at least); UI tests shorten it otherwise.
/// - `-uiTestAppLanguage <lproj>`: with `-uiTestInMemory`, Cue's interface starts in that language
///   (as if picked in Language & Region) without changing the simulator's. The interface language
///   always lives in memory under `-uiTestInMemory`.
struct LaunchOptions {
    var scriptRepository: ScriptRepository = LocalScriptRepository()
    var takeRepository: TakeRepository = LocalTakeRepository()
    var brandRepository: BrandRepository = LocalBrandRepository()
    /// The camera the recorder uses; nil is the real one (`AppServices.camera`).
    var recorderCamera: CameraControlling?
    var draftStore: QuickEditDraftStoring = QuickEditDraftStore()
    var exportCounter: ExportCountStoring = KeychainExportCountStore()
    var exportLedger: ExportLedgerStoring = FileExportLedgerStore()
    /// Nil is the real sharing (`VideoSharingService`).
    var sharing: VideoSharing?
    var defaults: UserDefaults = .standard
    /// UI tests and previews swap in rules read from the bundle only (no cache, no download).
    var platformRules: PlatformRulesService = PlatformRulesService()
    var writer: ScriptWriting = ScriptAIService()
    var credentialChecker: AppleIDCredentialChecking = AppleIDCredentialChecker()
    var remoteTransport: RemoteTransport = NearbyRemoteTransport()
    var languageStore: AppLanguageStoring = SystemAppLanguageStore()
    /// What the device can do in each language; the system's own answers unless a test gives a fixed list.
    var languageCapabilities: LanguageCapabilityChecking = AppleLanguageCapabilityChecker()
    /// Nil is the real microphone and recognizer.
    var dictation: DictationService?
    /// How long each few words of a script the AI writes stay on screen before the next arrive.
    var scriptRevealPause: Duration = .milliseconds(55)
    /// The first flight (onboarding) shows on a fresh install. UI tests turn it off unless `-uiTestOnboarding`.
    var showsOnboarding = true
    /// The system's permission prompts; UI tests answer them at once (`-uiTestPermissions granted|denied`).
    var permissions: PermissionRequesting?
    /// UI tests must not bring up the system's "icon changed" alert: the icon choice stays in memory.
    var isInMemory = false
    /// UI tests: the platforms' apps count as installed (`-uiTestAppsInstalled`).
    var appsAreInstalled = false
    /// UI tests of the My Cue Voice tip: its gates are open (`-uiTestVoiceTip`).
    var voiceTipSkipsGates = false
    /// UI tests of the star transition: it takes its real time (`-uiTestStarTransition`).
    var keepsStarTransitionTimings = false

    static func fromProcess() -> LaunchOptions {
        var options = LaunchOptions()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestInMemory") {
            options.isInMemory = true
            options.appsAreInstalled = arguments.contains("-uiTestAppsInstalled")
            let seeded = arguments.contains("-uiTestSeedSamples")
            options.scriptRepository = InMemoryScriptRepository(scripts: seeded ? SampleScripts.all : [])
            options.brandRepository = InMemoryBrandRepository()
            if arguments.contains("-uiTestDemoCamera") { options.recorderCamera = DemoCamera() }
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
            options.exportLedger = InMemoryExportLedgerStore()
            if options.appsAreInstalled { options.sharing = DemoVideoSharing() }
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
            // A sky that never stops drawing keeps a UI test from ever finding the app idle: tests start with it off
            // (`-uiTestSky calm|lively` brings it back for the ones that look at it).
            if let flag = arguments.firstIndex(of: "-uiTestSky"), arguments.indices.contains(flag + 1) {
                options.defaults.set(arguments[flag + 1], forKey: DefaultsKey.skyDensity)
            } else {
                options.defaults.set(SkyDensity.off.rawValue, forKey: DefaultsKey.skyDensity)
            }
            options.platformRules = PlatformRulesService(cacheURL: nil, remoteURL: nil)
            options.showsOnboarding = arguments.contains("-uiTestOnboarding")
            options.voiceTipSkipsGates = arguments.contains("-uiTestVoiceTip")
            options.keepsStarTransitionTimings = arguments.contains("-uiTestStarTransition")
            if let index = arguments.firstIndex(of: "-uiTestPermissions"), arguments.indices.contains(index + 1) {
                options.permissions = StubPermissions(grants: arguments[index + 1] != "denied")
            }
            options.remoteTransport = DemoRemoteTransport(connects: arguments.contains("-uiTestRemoteConnects"))
            let appLanguage = arguments.firstIndex(of: "-uiTestAppLanguage").flatMap { index in
                arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
            }
            options.languageStore = InMemoryAppLanguageStore(chosenLocalization: appLanguage)
            if let index = arguments.firstIndex(of: "-uiTestDictation"), arguments.indices.contains(index + 1),
               let scenario = ScriptedDictation.Scenario(rawValue: arguments[index + 1]) {
                let text = arguments.firstIndex(of: "-uiTestDictationText").flatMap { textIndex in
                    arguments.indices.contains(textIndex + 1) ? arguments[textIndex + 1] : nil
                } ?? "a video about my morning coffee routine"
                let scripted = ScriptedDictation(scenario: scenario, text: text)
                options.dictation = DictationService(audio: scripted, speech: scripted, microphone: scripted.microphone)
            }
            if arguments.contains("-uiTestStubAI") || arguments.contains("-uiTestNoAI") {
                options.writer = StubScriptWriter(available: !arguments.contains("-uiTestNoAI"))
                // A test never waits for words to arrive one by one.
                options.scriptRevealPause = .zero
            }
        }
        #endif
        return options
    }
}
