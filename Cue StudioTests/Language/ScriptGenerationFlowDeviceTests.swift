//
//  ScriptGenerationFlowDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What a creator gets from the card on the main screen, end to end and with the real Apple Intelligence
/// model: the idea goes through `ScriptStarter` (the arrow), the script page writes it
/// (`ScriptDetailViewModel.write`), and the script that ends up in the library is judged: a title, a
/// body of about the length asked for, no markdown or block labels, stage cues in ASCII brackets, in the
/// language of the idea, and, with "Write in my voice" on, the creator's catchphrase when it fits.
/// A language the model doesn't write opens a blank draft with the reason and writes nothing.
///
/// Opt-in and on a device (`TEST_RUNNER_CUE_AI_E2E=1`). Whether the text is *good* to a native speaker is
/// not something a test can say: it is reported and left to a human review.
@MainActor
@Suite("Writing from the card, on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct ScriptGenerationFlowDeviceTests {
    private struct Flow {
        let starter: ScriptStarter
        let library: ScriptLibraryService
        let presentation: PresentationService
        let ideaDraft: IdeaDraftService
        let toast: ToastService
        let writer: ScriptAIService
        let profile: CreatorProfileService
        let defaults: TestDefaults
        let rules: PlatformRulesService
    }

    private func makeFlow(preferred: [String] = ["en-US"], writesInMyVoice: Bool) throws -> Flow {
        // A long run on a device must not lock the screen: a locked app is in the background, where the model is rate limited.
        KeepScreenAwake.enable()
        let writer = ScriptAIService()
        guard writer.availability.onDevice else {
            let reason = writer.availability.reason ?? "unknown"
            try Test.cancel("Apple Intelligence isn't available on this device: \(reason)")
        }
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { .now })
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.addPhrase("Hey fam")
        profile.saveVoiceSetup(niches: [.lifestyle], vocabulary: .simple, sounds: [.casual, .confident])
        _ = profile.setWritesInMyVoice(writesInMyVoice)
        let rules = TestData.rulesService()
        let languages = TestData.languages(defaults: defaults.defaults, systemLanguages: preferred)
        let presentation = PresentationService()
        let ideaDraft = IdeaDraftService()
        let toast = ToastService()
        let transition = IdeaTransitionService()
        transition.speed = 0.01
        let starter = ScriptStarter(
            library: library, rules: rules, profile: profile, languages: languages, presentation: presentation,
            ideaDraft: ideaDraft, transition: transition, sky: SkyMemory(defaults: defaults.defaults), writer: writer, toast: toast
        )
        return Flow(
            starter: starter, library: library, presentation: presentation, ideaDraft: ideaDraft, toast: toast, writer: writer,
            profile: profile, defaults: defaults, rules: rules
        )
    }

    /// Sends `idea` through the arrow and lets the page write it. Returns the script as saved, and what the card asked for.
    private func write(_ idea: String, in flow: Flow) async throws -> (script: Script, request: ScriptRequest?) {
        flow.ideaDraft.text = idea
        let id = try #require(flow.starter.write())
        let request = flow.presentation.scriptsPath.first?.writing
        if let request {
            let viewModel = ScriptDetailViewModel(
                scriptID: id, ideaDraft: flow.ideaDraft, revealPause: .zero, library: flow.library,
                takes: TakeLibraryService(repository: FakeTakeRepository()),
                preferences: PreferencesService(defaults: flow.defaults.defaults), profile: flow.profile, rules: flow.rules,
                writer: flow.writer, toast: flow.toast
            )
            viewModel.write(request)
            for _ in 0..<600 where viewModel.page.isWriting {
                try await Task.sleep(for: .milliseconds(100))
            }
            print("FLOW page after writing: writing \(viewModel.page.isWriting) · error \(viewModel.page.writingError ?? "none") · toast \(flow.toast.message ?? "none")")
        }
        return (try #require(flow.library.script(id: id)), request)
    }

    nonisolated private static let ideas: [(CueLanguage, String)] = [
        (.english, "Why I stopped drinking coffee for thirty days and what changed"),
        (.portugueseBrazil, "Por que eu parei de tomar café por trinta dias e o que mudou"),
        (.spanish, "Por qué dejé de tomar café durante treinta días y qué cambió"),
        (.french, "Pourquoi j'ai arrêté le café pendant trente jours et ce qui a changé"),
        (.german, "Warum ich dreißig Tage lang keinen Kaffee getrunken habe und was sich geändert hat"),
        (.japanese, "三十日間コーヒーをやめて何が変わったのか"),
        (.chineseTraditional, "我三十天不喝咖啡之後發生了什麼改變"),
        (.dutch, "Waarom ik dertig dagen geen koffie dronk en wat er veranderde"),
    ]

    @Test(arguments: ideas)
    func theScriptThatEndsUpInTheLibraryIsAGoodOne(language: CueLanguage, idea: String) async throws {
        let flow = try makeFlow(writesInMyVoice: true)
        defer { flow.defaults.tearDown() }
        let (script, request) = try await write(idea, in: flow)
        let asked = try #require(request, "\(language.rawValue): the card didn't send the idea to the model")
        #expect(asked.language == language)
        #expect(asked.voice != nil)

        let words = ReadTime.wordCount(in: CueParser.stripCues(script.text))
        let low = ReadTime.words(for: asked.targetRange.lowerBound)
        let high = ReadTime.words(for: asked.targetRange.upperBound)
        let titleWords = script.title.split(whereSeparator: \.isWhitespace).count
        let hasMarkdown = script.text.contains("**") || script.text.contains("\n#") || script.text.hasPrefix("#")
        let usesWrongBrackets = script.text.contains("【") || script.text.contains("（pause")
        let right = OutputLanguageCheck.isPlausible(script.text, in: language)
        let catchphrase = script.text.localizedCaseInsensitiveContains("Hey fam")
        print(
            "FLOW \(language.rawValue): title “\(script.title)” (\(titleWords) words) · \(words) words for \(low)–\(high)"
                + " · language \(right) · markdown \(hasMarkdown) · catchphrase \(catchphrase) · finished \(script.isFinished)"
                + " · “\(script.text.prefix(110))”"
        )
        #expect(!script.title.isEmpty && titleWords <= 14, "\(language.rawValue): title “\(script.title)”")
        #expect(script.isFinished && !script.text.isEmpty)
        #expect(right, "\(language.rawValue): not in the language of the idea")
        #expect(!hasMarkdown && !usesWrongBrackets)
        // Length: the model is told the range; within a generous margin, and never empty or a runaway.
        let spaced = !language.writesWithoutSpaces
        if spaced { #expect(words >= low / 2 && words <= high * 2, "\(language.rawValue): \(words) words for \(low)–\(high)") }
    }

    @Test func withoutMyVoiceTheCatchphraseIsNotSent() async throws {
        let flow = try makeFlow(writesInMyVoice: false)
        defer { flow.defaults.tearDown() }
        let (_, request) = try await write("Why I stopped drinking coffee for thirty days", in: flow)
        #expect(request?.voice == nil)
    }

    @Test(arguments: [CueLanguage.thai, .hindi, .arabic, .indonesian])
    func aLanguageTheModelDoesntWriteOpensABlankDraftWithTheReason(language: CueLanguage) async throws {
        let flow = try makeFlow(writesInMyVoice: true)
        defer { flow.defaults.tearDown() }
        let idea: String = switch language {
        case .thai: "ทำไมฉันเลิกกินกาแฟสามสิบวันแล้วชีวิตเปลี่ยนไปมาก"
        case .hindi: "मैंने तीस दिन कॉफ़ी क्यों छोड़ी और क्या बदला"
        case .arabic: "لماذا توقفت عن شرب القهوة لمدة ثلاثين يومًا وماذا تغير"
        default: "Kenapa saya berhenti minum kopi selama tiga puluh hari dan apa yang berubah"
        }
        let (script, request) = try await write(idea, in: flow)
        #expect(request == nil, "\(language.rawValue): nothing may be sent to a model that can't write it")
        #expect(script.text.isEmpty)
        #expect(flow.toast.message == ScriptAIError.unsupportedLanguage.localizedDescription)
        print("FLOW \(language.rawValue): blank draft opened · “\(flow.toast.message ?? "")”")
    }
}
