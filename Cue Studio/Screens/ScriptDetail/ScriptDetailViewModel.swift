//
//  ScriptDetailViewModel.swift
//  Cue Studio
//

import Foundation

/// Reading and editing one script. The words are written on the page (`page`), which saves them as the creator goes
/// (`ScriptDetailViewModel+Page`).
@MainActor
@Observable
final class ScriptDetailViewModel {
    enum Sheet: String, Identifiable {
        case destination, hooks, improve, details, scriptType
        /// "Remind me…": a reminder for this script.
        case reminder
        var id: String { rawValue }
    }

    let scriptID: UUID
    var sheet: Sheet?
    /// The script's one page: the words being written and the little states around them.
    var page = ScriptPageState()
    /// The pending save of what is being written on the page.
    var pageCommitTask: Task<Void, Never>?
    /// The model writing into the page, if it is.
    var pageWritingTask: Task<Void, Never>?
    /// What the AI is to write into the page when it opens (an idea sent from the card), and the
    /// same request kept for "Try again".
    var pendingRequest: ScriptRequest?
    /// The words shown to the creator, a few at a time; zero with Reduce Motion.
    let revealPause: Duration
    let ideaDraft: IdeaDraftService?
    /// The paragraph to bring into view (a tap on a block of the Details sheet).
    var readScrollTarget: Int?
    var isNamingFolder = false
    var newFolderName = ""
    private(set) var runningTool: ScriptTool?
    private(set) var hookRotation = 0
    /// Hooks written by the model for this script; nil until asked, or without Apple Intelligence.
    private(set) var generatedHooks: [String]?
    private(set) var isLoadingHooks = false
    /// The platform a "Make a version for…" copy is being written for.
    private(set) var versionInProgress: Platform?

    let library: ScriptLibraryService
    let takes: TakeLibraryService
    let preferences: PreferencesService
    let profile: CreatorProfileService
    let rules: PlatformRulesService
    let writer: ScriptWriting
    let toast: ToastService
    /// Where the voice questions learn that a script was written in the creator's voice, or edited after.
    let voiceQuestions: VoiceQuestionScheduler?
    /// The idea's star while the AI writes into this page: it waits for the star to open the page, and an error is its exit.
    let transition: IdeaTransitionService?

    init(
        scriptID: UUID,
        startsEditing: Bool = false,
        writing request: ScriptRequest? = nil,
        ideaDraft: IdeaDraftService? = nil,
        revealPause: Duration = .milliseconds(55),
        library: ScriptLibraryService,
        takes: TakeLibraryService,
        preferences: PreferencesService,
        profile: CreatorProfileService,
        rules: PlatformRulesService,
        writer: ScriptWriting,
        toast: ToastService,
        voiceQuestions: VoiceQuestionScheduler? = nil,
        transition: IdeaTransitionService? = nil
    ) {
        self.voiceQuestions = voiceQuestions
        self.transition = transition
        self.scriptID = scriptID
        self.library = library
        self.takes = takes
        self.preferences = preferences
        self.profile = profile
        self.rules = rules
        self.writer = writer
        self.toast = toast
        self.ideaDraft = ideaDraft
        self.revealPause = revealPause
        pendingRequest = request
        loadPage(startsInDraft: startsEditing)
    }

    // MARK: - Reading

    var script: Script? { library.script(id: scriptID) }

    /// The words on the page (the ones arriving while the AI writes), the saved text before it loads.
    var workingText: String {
        page.isLoaded ? (page.revealed ?? page.text) : (script?.text ?? "")
    }

    var structure: ScriptStructure { script?.structure ?? .generic }

    /// What the Translate tool offers: every language but the one the script is written in.
    var translationLanguages: [CueLanguage] {
        let current = script?.language ?? LanguageDetector.language(in: workingText)
        return CueLanguage.allCases.filter { $0 != current }
    }

    /// The script's language (Auto-detect when nil). Never translates the text.
    func setLanguage(_ language: CueLanguage?) {
        library.setLanguage(language, of: scriptID)
    }

    var preset: PlatformPreset {
        rules.preset(for: script?.platform ?? .tiktok, monetizationGoals: profile.profile.monetizationGoals)
    }

    var blocks: [ScriptBlock] {
        ScriptBlocks.blocks(for: workingText, structure: structure, speed: preferences.prompter.speed)
    }

    var summaries: [BlockSummary] { ScriptBlocks.summaries(of: blocks) }

    var zone: LengthZone {
        LengthZone(text: workingText, preset: preset, speed: preferences.prompter.speed)
    }

    /// Seconds the hook runs when it is too long.
    var hookOverrun: TimeInterval? { ScriptBlocks.hookOverrun(in: blocks, structure: structure) }

    var scriptTakes: [Take] { takes.takes(for: scriptID) }

    var currentHook: String { ScriptTextEditing.opening(of: workingText) }

    var hookOptions: [String] {
        generatedHooks ?? ScriptTextEditing.hookOptions(from: structure.hooks, rotation: hookRotation)
    }

    /// Written by AI about a factual topic and not checked yet.
    var needsFactCheck: Bool { script?.factCheck ?? false }

    var isLanguageModelAvailable: Bool { writer.isLanguageModelAvailable }

    /// The tools above the keyboard: "In my voice" first, then the format's own.
    var tools: [ScriptTool] { [.inMyVoice] + structure.tools }

    /// Platforms "Make a version for…" offers: every one but the script's.
    var versionPlatforms: [Platform] {
        Platform.allCases.filter { $0 != script?.platform }
    }

    var rewriteContext: RewriteContext {
        RewriteContext(
            structure: structure,
            platform: script?.platform ?? .tiktok,
            idealRange: preset.idealRange,
            sourceLanguage: textLanguage,
            voice: profile.profile.voice(inLanguage: textLanguage?.languageCode?.identifier, idea: workingText)
        )
    }

    /// The language the script is written in, as the model must keep it: the script's own, else read
    /// from its text (any language, not only the ones Cue offers).
    private var textLanguage: Locale.Language? {
        script?.language?.locale.language ?? LanguageDetector.dominantLanguage(in: workingText)
    }

    // MARK: - Destination

    func setPlatform(_ platform: Platform) {
        library.update(scriptID) { $0.platform = platform }
        sheet = nil
        toast.show(String(localized: "Create for \(platform.destinationName)"))
    }

    // MARK: - Hooks

    func replaceHook(with hook: String) {
        library.update(scriptID) { $0.text = ScriptTextEditing.replacingOpening(of: $0.text, with: hook) }
        syncPage()
        sheet = nil
        toast.show(String(localized: "Hook replaced · ~\(DurationText.short(ReadTime.seconds(for: hook, speed: preferences.prompter.speed)))"))
    }

    /// "Pick a new hook": the model writes three for this script when it can; otherwise the
    /// format's own ideas.
    func openHooks() async {
        sheet = .hooks
        guard generatedHooks == nil else { return }
        await loadHooks()
    }

    func showMoreHooks() async {
        if writer.isLanguageModelAvailable {
            await loadHooks()
        } else {
            hookRotation += 1
        }
    }

    private func loadHooks() async {
        guard !isLoadingHooks, writer.isLanguageModelAvailable else { return }
        isLoadingHooks = true
        defer { isLoadingHooks = false }
        if let hooks = try? await writer.hooks(for: workingText, context: rewriteContext), !hooks.isEmpty {
            generatedHooks = hooks
        } else {
            generatedHooks = nil
            hookRotation += 1
        }
    }

    // MARK: - Fact check

    func markFactChecked() {
        library.markFactChecked(scriptID)
        toast.show(String(localized: "Marked as fact-checked"))
    }

    // MARK: - Tools

    func run(_ tool: ScriptTool, language: CueLanguage? = nil) async {
        guard runningTool == nil else { return }
        switch tool {
        case .newHooks:
            await openHooks()
        case .addDisclosure:
            guard !ScriptTextEditing.hasDisclosure(workingText) else {
                toast.show(String(localized: "Disclosure is already first"))
                return
            }
            adopt(
                ScriptTextEditing.addingDisclosure(to: workingText, language: script?.language),
                message: String(localized: "Disclosure added up front")
            )
        case .translate:
            // The target is always the creator's pick; there is no language to translate into by default.
            guard let language else { return }
            await translate(into: language)
        default:
            await rewrite(with: tool)
        }
    }

    /// What a tool wrote becomes the script's words, saved at once (a new version when takes were made
    /// from the old ones). The toast says what happened, and its Undo puts the old words back.
    private func adopt(_ text: String, message: String) {
        guard let script else { return }
        let before = (text: script.text, version: script.version)
        let bumpsVersion = !scriptTakes.isEmpty
        library.update(scriptID) { script in
            script.text = text
            if bumpsVersion { script.version += 1 }
        }
        syncPage()
        sheet = nil
        toast.show(message, duration: .seconds(4), action: ToastAction(title: String(localized: "Undo")) { [weak self] in
            guard let self else { return }
            library.update(scriptID) { script in
                script.text = before.text
                script.version = before.version
            }
            syncPage()
            toast.show(String(localized: "Undone"))
        })
    }

    private func rewrite(with tool: ScriptTool) async {
        guard script != nil else { return }
        guard writer.isLanguageModelAvailable else {
            toast.show(writer.unavailableReason ?? String(localized: "AI isn't available now"))
            return
        }
        let before = workingText
        guard ReadTime.wordCount(in: before) > 0 else {
            toast.show(String(localized: "Write something first, then Cue can improve it"))
            return
        }
        runningTool = tool
        defer { runningTool = nil }
        do {
            let result = try await writer.rewriteReported(before, with: tool, context: rewriteContext)
            let notice = RewriteNotice.after(tool, before: before, result: result, done: doneMessage(for: tool), idealRange: preset.idealRange)
            if notice.changesScript {
                adopt(result.text, message: notice.message)
            } else {
                sheet = nil
                toast.show(notice.message)
            }
        } catch {
            showFailure(error)
        }
    }

    private func translate(into language: CueLanguage) async {
        guard let script else { return }
        guard writer.isLanguageModelAvailable else {
            toast.show(writer.unavailableReason ?? String(localized: "AI isn't available now"))
            return
        }
        guard ReadTime.wordCount(in: workingText) > 0 else {
            toast.show(String(localized: "Write something first, then Cue can improve it"))
            return
        }
        runningTool = .translate
        defer { runningTool = nil }
        do {
            var context = rewriteContext
            context.language = language
            let result = try await writer.rewriteReported(workingText, with: .translate, context: context)
            guard !result.isUntouched else {
                toast.show(String(localized: "Couldn’t write it · Try again"))
                return
            }
            // A translation is a new script in the new language; the original stays as written.
            library.create(
                title: String(localized: "\(script.displayTitle) (\(language.localizedName))"),
                text: result.text, platform: script.platform, type: script.type, folder: script.folder,
                language: language
            )
            sheet = nil
            var message = String(localized: "\(language.localizedName) version saved")
            if result.leftAsWritten > 0 {
                message += " · " + String(localized: "\(result.leftAsWritten) of \(result.parts) parts left as written")
            }
            toast.show(message)
        } catch {
            showFailure(error)
        }
    }

    // MARK: - Versions

    /// "Make a version for…": a copy fitted to another platform's length and pace, with its preset.
    func makeVersion(for platform: Platform) async {
        guard let script, versionInProgress == nil else { return }
        guard writer.isLanguageModelAvailable else {
            toast.show(writer.unavailableReason ?? String(localized: "AI isn't available now"))
            return
        }
        versionInProgress = platform
        defer { versionInProgress = nil }
        toast.show(String(localized: "Writing the \(platform.label) version…"))
        do {
            var context = rewriteContext
            context.platform = platform
            let range = rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals).idealRange
            context.idealRange = range
            let result = try await writer.rewriteReported(script.text, with: .fitToTime, context: context)
            library.create(
                title: String(localized: "\(script.displayTitle) (\(platform.label))"),
                text: result.text, platform: platform, type: script.type, folder: script.folder,
                language: script.language
            )
            var message = String(localized: "\(platform.label) version saved")
            // The version is the script as the platform's length asks it, or says how far it got.
            if let length = RewriteNotice.lengthNote(words: ReadTime.wordCount(in: result.text), idealRange: range) {
                message += " · " + length
            }
            toast.show(message)
        } catch {
            showFailure(error)
        }
    }

    /// An AI tool failed: the reason in Cue's words. Stopping it is not a failure and says nothing.
    private func showFailure(_ error: any Error) {
        guard !(error is CancellationError) else { return }
        toast.show(error.localizedDescription)
    }

    private func doneMessage(for tool: ScriptTool) -> String {
        switch tool {
        case .fitToTime:
            let range = DurationText.clock(preset.idealRange.lowerBound) + "–" + DurationText.clock(preset.idealRange.upperBound)
            return String(localized: "Fitted to \(range)")
        case .inMyVoice:
            let sounds = profile.profile.sounds.prefix(2).map { $0.label.lowercased() }.joined(separator: ", ")
            return String(localized: "Rewrote in your voice · \(sounds)")
        case .moreEnergy: return String(localized: "Rewrote with more energy")
        case .fixGrammar: return String(localized: "Grammar fixed")
        case .strongerCTA: return String(localized: "Call to action strengthened")
        case .moreHuman: return String(localized: "Made it sound more human")
        case .lessDefensive: return String(localized: "Removed defensive lines")
        case .shorterAndDirect: return String(localized: "Made it shorter and more direct")
        case .newHooks, .addDisclosure, .translate: return String(localized: "Done")
        }
    }

    // MARK: - Library actions

    func duplicate() {
        library.duplicate([scriptID])
        toast.show(String(localized: "Duplicated"))
    }

    func move(to folder: String?) {
        library.move([scriptID], toFolder: folder)
        toast.show(folder.map { String(localized: "Moved to “\($0)”") } ?? String(localized: "Removed from folder"))
    }

    func startNewFolder() {
        newFolderName = ""
        isNamingFolder = true
    }

    func confirmNewFolder() {
        guard let name = library.createFolder(named: newFolderName) else {
            if !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty {
                toast.show(String(localized: "That folder already exists"))
            }
            return
        }
        move(to: name)
    }

    /// Deletes, with Undo for 4 s as the list does: a script is a lot of words to lose to one tap next to "Share".
    func delete() {
        guard let script else { return }
        library.delete([scriptID])
        toast.show(String(localized: "Script deleted"), action: ToastAction(title: String(localized: "Undo")) { [library] in library.restore([script]) })
    }
}
