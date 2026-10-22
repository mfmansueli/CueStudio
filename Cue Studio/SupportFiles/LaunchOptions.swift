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
/// - `-uiTestLongTake <seconds>`: "3 morning habits" Take 3 becomes a full-size take that long, with captions (device export
///   measurements); `-uiTestContinuedTasks` turns iOS's continued tasks on for exports in UI tests.
/// - `-uiTestSlowExport`: the review's exports take a few seconds, so its progress can be seen; `-uiTestStoppedExport`: Take 3's
///   export stopped with Cue the last time, and its review says so.
/// - `-uiTestDemoEdit`: "3 morning habits" Take 3 opens in the editor as the v10 design's demo
///   (`SampleEdit`); with `-uiTestDemoTranscript` its words were heard too, for Edit by text.
/// - `-uiTestSampleVideo`: with the sample takes, writes small real videos behind the "3 morning
///   habits" takes, so Quick edit can play, scrub and trim them.
/// - `-uiTestDemoCamera`: the recorder's camera records with no hardware (a small real video per take), for the Simulator.
/// - `-uiTestAppsInstalled`: with the above, the platforms' apps count as installed and take the video (`DemoVideoSharing`:
///   the send-off after "Share to").
/// - `-uiTestSky <off|serene|adrift|interstellar>`: with the above, the sky starts like that (off otherwise: an endless animation
///   keeps UI tests from finding the app idle).
/// - `-uiTestRemoteConnects`: with the above, a remote "connects" right after pairing starts (UI
///   tests have no second device). Without it the remote link stays offline.
/// - `-uiTestDictation <speech|denied|unavailable|silence>`: dictation without a microphone or a
///   model (the simulator has neither): it hears `-uiTestDictationText <words>` a word at a time
///   (`speech`), or is refused the microphone, can't recognize the language, or hears nothing.
/// - `-uiTestVoiceFollowing <listening|preparing|unavailable>`: the prompter's Voice Following recognition is scripted (the simulator
///   can't recognize speech): it listens and hears nothing, stays getting ready, or can't follow the words here (`ScriptedVoiceFollowing`).
/// - `-uiTestOnboarding`: with the above, the first flight shows (it is off in UI tests otherwise).
/// - `-uiTestPermissions <granted|denied>`: the first flight's permission prompts are answered at once.
/// - `-uiTestVoyage`: the first voyage (the first video guide) is on; without it no UI test sees its card, strip or tips.
/// - `-uiTestVoiceTip`: the My Cue Voice tip needs no second day, script, wait or cap (tests of the tip itself); without it the
///   tip stays away in UI tests (they open the app on one day).
/// - `-uiTestStarTransition`: the idea's star transition keeps its real timings (3 s at least); UI tests shorten it otherwise.
/// - `-uiTestSlowWriting`: with the stub writer, the script's words arrive on the page slowly enough to look at the page mid-writing.
/// - `-uiTestRealWriting`: the words arrive at the real pace (55 ms a step), and `-uiTestLongScript` makes the stub's script run well past
///   a minute and a half: together, how a long script is written, followed and settled on the page.
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
/// - `-uiTestWriterStalls`: with `-uiTestStubAI`, the model never answers (the star transition's slow states).
/// - `-uiTestIdeasSlow`: with `-uiTestStubAI`, every batch of ideas takes 12 s (Find inspiration waiting for the next ones: longer than tapping through six).
/// - `-uiTestIdeasFail`: with `-uiTestStubAI`, every batch of ideas fails (Find inspiration's "Try again").
/// - `-uiTestAIUnavailable <language|device|off|preparing|cue>`: with `-uiTestStubAI`, Apple Intelligence can't draft, and why: Thai,
///   Hindi, Indonesian and Arabic aren't drafted (`language`), the iPhone can't run it, it is off in iOS, the model is getting ready, or
///   Cue's own On-device AI switch is off (`DraftingAvailability`).
/// - `-uiTestScriptLanguage <locale>`: with `-uiTestInMemory`, Language & Region's Script Language starts on that language (`th-TH`).
/// - `-uiTestChapterAt <seconds>`: the opening of the chapter on screen (1.2 to 1.6) stands still at that second of its timeline.
/// - `-uiTestWelcomeOpening`: the welcome's star opening (1.1) plays in full (about 8 s); UI tests otherwise show its final state.
/// - `-uiTestSceneCapture <on|off>`: the scene starts recorded or mirrored (`on`) or not, and the test runner can start and stop
///   it while the app runs (`SimulatedSceneCapture`): the video previews hide behind `CaptureShield`. Read in `CueStudioApp`.
/// - `-uiTestNotificationAuth <notDetermined|refuses|authorized|denied|provisional>`: with `-uiTestInMemory`, notifications use an in-memory
///   center that answers the permission at once (no system prompt; `notDetermined` by default, which allows when asked).
/// - `-uiTestNotificationTap <script|cleanUp|share|deletedScript|invalid|duplicate|routine|logbook|universe>`: Cue opens as if launched
///   from that notification (`DebugNotificationTaps`).
/// - `-uiTestNotificationInvite`: Cue's invitation to allow notifications may show (UI tests leave it out otherwise, like the voice tip).
/// - `-uiTestTopics <list>`: with `-uiTestInMemory`, the creator holds these topics (comma separated: a first-flight topic by its id, `fitness`,
///   or one they typed, `custom:Daily Routine`): Find inspiration's filters with several topics, only typed ones, or none (no argument).
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
    /// Nil is the model on this iPhone (`AppleWritingStyleReader`).
    var styleReader: (any WritingStyleReading)?
    var credentialChecker: AppleIDCredentialChecking = AppleIDCredentialChecker()
    var remoteTransport: RemoteTransport = NearbyRemoteTransport()
    var languageStore: AppLanguageStoring = SystemAppLanguageStore()
    /// What the device can do in each language; the system's own answers unless a test gives a fixed list.
    var languageCapabilities: LanguageCapabilityChecking = AppleLanguageCapabilityChecker()
    /// Nil is the real microphone and recognizer.
    var dictation: DictationService?
    /// The prompter's Voice Following recognition; nil is the real one (`-uiTestVoiceFollowing`).
    var prompterSpeech: SpeechTranscribing?
    /// How long each few words of a script the AI writes stay on screen before the next arrive.
    var scriptRevealPause: Duration = .milliseconds(55)
    /// The first flight (onboarding) shows on a fresh install. UI tests turn it off unless `-uiTestOnboarding`.
    var showsOnboarding = true
    /// The system's permission prompts; UI tests answer them at once (`-uiTestPermissions granted|denied`).
    var permissions: PermissionRequesting?
    /// UI tests must not bring up the system's "icon changed" alert: the icon choice stays in memory.
    var isInMemory = false
    /// iOS's continued tasks for exports (off in UI tests unless `-uiTestContinuedTasks`).
    var usesContinuedTasks = true
    /// `-uiTestSlowExport`: the review's exports take a few seconds (`SlowVideoExporter`).
    var slowExports = false
    /// UI tests: the platforms' apps count as installed (`-uiTestAppsInstalled`).
    var appsAreInstalled = false
    /// UI tests of the My Cue Voice tip: its gates are open (`-uiTestVoiceTip`).
    var voiceTipSkipsGates = false
    /// UI tests of the first voyage: the guide is on (`-uiTestVoyage`); every other UI test runs without it.
    var showsVoyage = false
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
    /// Nil is the system's notification center; UI tests use one in memory that never shows the permission prompt.
    var notificationCenter: NotificationCenterClient?
    /// UI tests: Cue opens as if launched from this notification (`-uiTestNotificationTap`).
    var notificationTap: String?
    /// Cue's invitation to allow notifications; UI tests leave it out unless `-uiTestNotificationInvite`.
    var notificationInvites = true

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

    #if DEBUG
    /// `-uiTestTopics fitness,custom:Daily Routine`: a profile that holds those topics and nothing else.
    /// `-uiTestScriptLanguage` and `-uiTestAIUnavailable`: the Script Language to start on, and why Apple Intelligence can't draft. Cue's own
    /// switch (`cue`) is a preference that Settings › Privacy & AI data reads from the defaults; the others are the stub writer's.
    private static func readDrafting(_ arguments: [String], into defaults: UserDefaults) -> StubScriptWriter.Unavailable? {
        if let index = arguments.firstIndex(of: "-uiTestScriptLanguage"), arguments.indices.contains(index + 1),
           let language = CueLanguage(rawValue: arguments[index + 1]) {
            defaults.set(language.rawValue, forKey: DefaultsKey.scriptLanguage)
        }
        guard let index = arguments.firstIndex(of: "-uiTestAIUnavailable"), arguments.indices.contains(index + 1),
              let unavailable = StubScriptWriter.Unavailable(rawValue: arguments[index + 1]) else { return nil }
        if unavailable == .cue { defaults.set(false, forKey: DefaultsKey.onDeviceAI) }
        return unavailable
    }

    private static func writeTopics(_ list: String, to defaults: UserDefaults) {
        var profile = CreatorProfile()
        for item in list.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !item.isEmpty {
            if item.hasPrefix("custom:") {
                profile.customTopics.append(String(item.dropFirst("custom:".count)))
            } else if let niche = Niche(rawValue: item) {
                profile.niches.append(niche)
            }
        }
        defaults.set(try? JSONEncoder().encode(profile), forKey: DefaultsKey.creatorProfile)
    }
    #endif

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
                takes[index].edit = SampleEdit.make(aspect: takes[index].aspect, heard: arguments.contains("-uiTestDemoTranscript"))
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
            options.usesContinuedTasks = arguments.contains("-uiTestContinuedTasks")
            options.slowExports = arguments.contains("-uiTestSlowExport")
            let habits = takes.filter { $0.scriptID == SampleScripts.morningHabits.id }
            // A long, full-size take with captions for measuring exports on a device (`-uiTestLongTake <seconds>`).
            if let flag = arguments.firstIndex(of: "-uiTestLongTake"), arguments.indices.contains(flag + 1),
               let seconds = Double(arguments[flag + 1]), let index = takes.firstIndex(where: {
                   $0.scriptID == SampleScripts.morningHabits.id && $0.number == 3
               }) {
                takes[index].duration = seconds
                takes[index].fileName = "sample-long-\(Int(seconds)).mov"
                takes[index].edit = SampleEdit.long(seconds: seconds, aspect: takes[index].aspect)
                try? repository.saveTakes(takes)
                SampleVideo.writeLong(to: repository.videoURL(named: takes[index].fileName), seconds: seconds)
            }
            UITestLeftovers.removeOldExports()
            if arguments.contains("-uiTestSampleVideo") {
                SampleVideo.writeMissing(for: habits, in: repository)
            } else {
                SampleVideo.remove(for: habits, in: repository)
            }
            let suite = "studio.cue.uitests"
            UserDefaults().removePersistentDomain(forName: suite)
            options.defaults = UserDefaults(suiteName: suite) ?? .standard
            // "3 morning habits" Take 3 was exporting when Cue last stopped (its review shows the stopped notice).
            if arguments.contains("-uiTestStoppedExport"), let take = takes.first(where: {
                $0.scriptID == SampleScripts.morningHabits.id && $0.number == 3
            }) {
                options.defaults.set([take.id.uuidString], forKey: DefaultsKey.exportsInFlight)
            }
            // A sky that never stops drawing keeps a UI test from ever finding the app idle: tests start with it off
            // (`-uiTestSky serene|adrift|interstellar` brings it back for the ones that look at it).
            if let flag = arguments.firstIndex(of: "-uiTestSky"), arguments.indices.contains(flag + 1) {
                options.defaults.set(arguments[flag + 1], forKey: DefaultsKey.skyDensity)
            } else {
                options.defaults.set(SkyDensity.off.rawValue, forKey: DefaultsKey.skyDensity)
            }
            if let index = arguments.firstIndex(of: "-uiTestTopics"), arguments.indices.contains(index + 1) {
                Self.writeTopics(arguments[index + 1], to: options.defaults)
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
            options.showsVoyage = arguments.contains("-uiTestVoyage")
            options.keepsStarTransitionTimings = arguments.contains("-uiTestStarTransition")
            options.animationsOff = arguments.contains("-uiTestFastAnimations")
            options.keepsWelcomeOpening = arguments.contains("-uiTestWelcomeOpening")
            options.showsFirstStar = arguments.contains("-uiTestFirstStar")
            Self.readFrozenTimes(arguments, into: &options)
            if let index = arguments.firstIndex(of: "-uiTestPermissions"), arguments.indices.contains(index + 1) {
                options.permissions = StubPermissions(grants: arguments[index + 1] != "denied")
            }
            options.remoteTransport = DemoRemoteTransport(connects: arguments.contains("-uiTestRemoteConnects"))
            let notificationStart = arguments.firstIndex(of: "-uiTestNotificationAuth").flatMap { index in
                arguments.indices.contains(index + 1) ? InMemoryNotificationCenter.Start(rawValue: arguments[index + 1]) : nil
            }
            options.notificationCenter = InMemoryNotificationCenter(start: notificationStart ?? .notDetermined)
            options.notificationInvites = arguments.contains("-uiTestNotificationInvite")
            options.notificationTap = arguments.firstIndex(of: "-uiTestNotificationTap").flatMap { index in
                arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
            }
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
            if let index = arguments.firstIndex(of: "-uiTestVoiceFollowing"), arguments.indices.contains(index + 1),
               let scenario = ScriptedVoiceFollowing.Scenario(rawValue: arguments[index + 1]) {
                options.prompterSpeech = ScriptedVoiceFollowing(scenario: scenario)
            }
            let unavailable = Self.readDrafting(arguments, into: options.defaults)
            if arguments.contains("-uiTestStubAI") || arguments.contains("-uiTestNoAI") {
                options.writer = StubScriptWriter(
                    available: !arguments.contains("-uiTestNoAI"), stalls: arguments.contains("-uiTestWriterStalls"),
                    ideasDelay: arguments.contains("-uiTestIdeasSlow") ? .seconds(12) : nil, ideasFail: arguments.contains("-uiTestIdeasFail"),
                    writesLong: arguments.contains("-uiTestLongScript"), unavailable: unavailable
                )
                options.styleReader = arguments.contains("-uiTestNoAI") ? NoStyleReader() : StubStyleReader()
                // A test never waits for words to arrive one by one, unless it is looking at them arrive (slowly, or at the real pace).
                options.scriptRevealPause = arguments.contains("-uiTestSlowWriting") ? .milliseconds(2_000)
                    : arguments.contains("-uiTestRealWriting") ? .milliseconds(55) : .zero
            }
        }
        #endif
        return options
    }
}
