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
/// - `-uiTestSlowWriting`: with the stub writer, the script's words arrive on the page slowly enough to look at the page mid-writing.
/// - `-uiTestFastAnimations`: with the above, no animations (UIKit's sheets and pushes, SwiftUI's transactions), so a UI test
///   never waits for one to end; `CueApp.launch` passes it unless a test asks for real animations.
/// - `-uiTestExportsLeft <0...5>`: the free exports that are left (5 without it): 1 is the last one, 0 asks "Your video is ready" on export.
/// - `-uiTestUniverse <sample|newYear|newAccount>`: what "Your universe" holds (the board's APP DATA panel; see `UniverseSeed`).
/// - `-uiTestFakeShareSheet`: a stand-in with Complete and Cancel takes the place of the system share sheet.
/// - `-uiTestShareQueue`: a "Share to universe" queue left for the sample take (the Continue posting card).
/// - `-uiTestStoryAt <seconds>`: the milestone and first-star stories stand still at that second.
/// - `-uiTestFirstStar` / `-uiTestMilestone <videos>`: the review opens on the first-star (1.7) / milestone (8.3) story.
/// - `-uiTestSendOffAt <seconds>`: the send-off (8.2) stands still at that second of its timeline.
/// - `-uiTestProAt <seconds>`: the Pro opening stands still at that second of its timeline (to take its pictures).
/// - `-uiTestWelcomeAt <seconds>`: the welcome's opening stands still at that second of its timeline (to take its pictures).
/// - `-uiTestOnboardingStep <welcome|universe|voyage|script|voice|practice>`: with `-uiTestOnboarding`, the first flight opens on that chapter.
/// - `-uiTestTopicBirthAt <seconds>`: on 1.2, three topics are picked and the last one's birth stands still at that second after the pick.
/// - `-uiTestPlatformAt <seconds>`: on 1.3, TikTok is picked and the light of the pick stands still at that second after the pick.
/// - `-uiTestWriterStalls`: with `-uiTestStubAI`, the model never answers the first message (its slow states, 1.4b).
/// - `-uiTestChapterAt <seconds>`: the opening of the chapter on screen (1.2 to 1.6) stands still at that second of its timeline.
/// - `-uiTestWelcomeOpening`: the welcome's star opening (1.1) plays in full (about 8 s); UI tests otherwise show its final state.
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
    /// Debug builds give a new install its free exports back (the Keychain count outlives a reinstall). Not under UI tests:
    /// their throwaway defaults would make every launch look like a new install.
    var resetsExportsOnNewInstall = false
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
    /// UI tests: nothing animates (`-uiTestFastAnimations`).
    var animationsOff = false
    /// UI tests of the welcome: the star's opening plays in full (`-uiTestWelcomeOpening`).
    var keepsWelcomeOpening = false
    /// UI tests: a stand-in for the system share sheet (`-uiTestFakeShareSheet`).
    var fakesShareSheet = false
    /// UI tests: the welcome's opening is frozen at this second (`-uiTestWelcomeAt`).
    var welcomeFrozenTime: Double?
    /// UI tests: the Pro opening is frozen at this second (`-uiTestProAt`).
    var proFrozenTime: Double?
    /// UI tests: the first flight opens on this chapter (`-uiTestOnboardingStep`) and its opening stands still at a second (`-uiTestChapterAt`).
    var onboardingStep: OnboardingStep?
    var chapterFrozenTime: Double?
    var topicBirthFrozenAge: Double?
    var platformPickFrozenAge: Double?
    /// UI tests: the send-off stands still at this second (`-uiTestSendOffAt`).
    var sendOffFrozenTime: Double?
    /// UI tests: the review opens on the first-star story (`-uiTestFirstStar`) or the milestone story (`-uiTestMilestone <videos>`).
    var showsFirstStar = false
    /// UI tests: the milestone / first-star stories stand still at this second (`-uiTestStoryAt`).
    var storyFrozenTime: Double?
    var milestoneToShow: Int?
    /// UI tests: how many of the free exports are already used (`-uiTestExportsLeft`).
    var exportsUsed = 0

    /// The arguments that stand a screen still at a second of its timeline (to take its pictures), and the milestone to open on.
    private static func readFrozenTimes(_ arguments: [String], into options: inout LaunchOptions) {
        func value(_ name: String) -> String? {
            arguments.firstIndex(of: name).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        }
        options.storyFrozenTime = value("-uiTestStoryAt").flatMap(Double.init)
        options.milestoneToShow = value("-uiTestMilestone").flatMap(Int.init)
        options.sendOffFrozenTime = value("-uiTestSendOffAt").flatMap(Double.init)
        options.proFrozenTime = value("-uiTestProAt").flatMap(Double.init)
        options.welcomeFrozenTime = value("-uiTestWelcomeAt").flatMap(Double.init)
        options.chapterFrozenTime = value("-uiTestChapterAt").flatMap(Double.init)
        options.topicBirthFrozenAge = value("-uiTestTopicBirthAt").flatMap(Double.init)
        options.platformPickFrozenAge = value("-uiTestPlatformAt").flatMap(Double.init)
        options.onboardingStep = value("-uiTestOnboardingStep").flatMap { name in OnboardingStep.allCases.first { "\($0)" == name } }
    }

    static func fromProcess() -> LaunchOptions {
        var options = LaunchOptions()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        options.resetsExportsOnNewInstall = !arguments.contains("-uiTestInMemory")
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
            if let index = arguments.firstIndex(of: "-uiTestExportsLeft"), arguments.indices.contains(index + 1), let left = Int(arguments[index + 1]) {
                options.exportsUsed = max(0, UsagePolicy.freeExports - left)
            }
            options.exportCounter = InMemoryExportCountStore(count: options.exportsUsed)
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
            if let index = arguments.firstIndex(of: "-uiTestUniverse"), arguments.indices.contains(index + 1),
               let kind = UniverseSeed.Kind(rawValue: arguments[index + 1]) {
                UniverseSeed.apply(kind, to: options.defaults)
            }
            options.fakesShareSheet = arguments.contains("-uiTestFakeShareSheet")
            // A "Share to universe" queue the creator left: TikTok then Reels for the sample take (`-uiTestShareQueue`).
            let habits3 = takes.first { $0.scriptID == SampleScripts.morningHabits.id && $0.number == 3 }
            if arguments.contains("-uiTestShareQueue"), let take = habits3 {
                let queue = ShareQueue(takeID: take.id, operationID: UUID(), title: take.scriptTitle, networks: [.tiktok, .reels])
                options.defaults.set(try? JSONEncoder().encode([queue]), forKey: DefaultsKey.shareQueues)
            }
            options.platformRules = PlatformRulesService(cacheURL: nil, remoteURL: nil)
            options.showsOnboarding = arguments.contains("-uiTestOnboarding")
            options.voiceTipSkipsGates = arguments.contains("-uiTestVoiceTip")
            options.keepsStarTransitionTimings = arguments.contains("-uiTestStarTransition")
            options.animationsOff = arguments.contains("-uiTestFastAnimations")
            options.keepsWelcomeOpening = arguments.contains("-uiTestWelcomeOpening")
            options.showsFirstStar = arguments.contains("-uiTestFirstStar")
            Self.readFrozenTimes(arguments, into: &options)
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
                options.writer = StubScriptWriter(available: !arguments.contains("-uiTestNoAI"), stalls: arguments.contains("-uiTestWriterStalls"))
                // A test never waits for words to arrive one by one, unless it is looking at them arrive.
                options.scriptRevealPause = arguments.contains("-uiTestSlowWriting") ? .milliseconds(2_000) : .zero
            }
        }
        #endif
        return options
    }
}
