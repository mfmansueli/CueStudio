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
    /// The script the AI wrote, whole, while its words are still arriving on the page (saved already: leaving keeps all of it).
    var arrivedScript: GeneratedScript?
    /// The time iOS gives Cue in the background while a script is written (`ApplicationGrace`); a test stands in for it.
    var writingGrace: @MainActor () -> @MainActor () -> Void = { ApplicationGrace.begin(named: "Cue script") }
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
    /// The page is on screen (it is made for the page that opens, and its view says when it leaves): a result that arrives after the creator
    /// left it names the script it was for (`sayResult`).
    var isOnScreen = true

    let library: ScriptLibraryService
    let takes: TakeLibraryService
    let preferences: PreferencesService
    let profile: CreatorProfileService
    let rules: PlatformRulesService
    let writer: ScriptWriting
    /// Writes the page when the request chose Ultra (`ScriptRequest.engine`); nil where Ultra can't be reached (previews, older tests).
    let ultra: UltraScriptWriting?
    let toast: ToastService
    /// Where the voice questions learn that a script was written in the creator's voice, or edited after.
    let voiceQuestions: VoiceQuestionScheduler?
    /// The idea's star while the AI writes into this page: it waits for the star to open the page, and an error is its exit.
    let transition: IdeaTransitionService?
    /// Where Cue's draft is kept until the script is recorded, to learn from what the creator changes.
    let draftLearning: DraftLearningService?

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
        ultra: UltraScriptWriting? = nil,
        toast: ToastService,
        voiceQuestions: VoiceQuestionScheduler? = nil,
        transition: IdeaTransitionService? = nil,
        draftLearning: DraftLearningService? = nil
    ) {
        self.voiceQuestions = voiceQuestions
        self.draftLearning = draftLearning
        self.transition = transition
        self.scriptID = scriptID
        self.library = library
        self.takes = takes
        self.preferences = preferences
        self.profile = profile
        self.rules = rules
        self.writer = writer
        self.ultra = ultra
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

    /// The language whose pace times the script (`ReadTime.pace(for:)`): its own, or read from the words on the page, as the list does.
    var paceLanguage: CueLanguage? { script?.language ?? LanguageDetector.quickLanguage(in: workingText) }

    var blocks: [ScriptBlock] {
        ScriptBlocks.blocks(for: workingText, structure: structure, language: paceLanguage)
    }

    var summaries: [BlockSummary] { ScriptBlocks.summaries(of: blocks) }

    var zone: LengthZone {
        LengthZone(text: workingText, preset: preset, language: paceLanguage)
    }

    /// Seconds the hook runs when it is too long.
    var hookOverrun: TimeInterval? { ScriptBlocks.hookOverrun(in: workingText, structure: structure, language: paceLanguage) }

    var scriptTakes: [Take] { takes.takes(for: scriptID) }

    var currentHook: String { ScriptHook.text(of: workingText) }

    var hookOptions: [String] {
        generatedHooks ?? ScriptTextEditing.hookOptions(from: templateHooks, rotation: hookRotation, language: paceLanguage)
    }

    /// The format's ready-made hooks in the script's language (read from the words when the script doesn't say; the interface's when neither
    /// does): a hook is read to camera, so a Portuguese script never gets English ones because the app is in English.
    private var templateHooks: [String] {
        let language = script?.language ?? LanguageDetector.language(in: workingText)
        return (script?.type?.structure(hooksIn: language) ?? ScriptStructure.generic(hooksIn: language)).hooks
    }

    /// Written by AI about a factual topic and not checked yet.
    var needsFactCheck: Bool { script?.factCheck ?? false }

    var isLanguageModelAvailable: Bool { writer.isLanguageModelAvailable }

    /// Whether Apple Intelligence can draft in this script's language, with why not: the tools that need the model say so before anything is
    /// sent (Improve's rows, the selection bar, Shorter, a version for another platform).
    var drafting: DraftingAvailability { writer.drafting(in: textLanguage.map { [$0] } ?? []) }

    var canDraft: Bool { drafting.isAvailable }

    /// Whether Apple Intelligence drafts in `language` (a Translate target), asked only of the language: nil when it does, or when the
    /// reason isn't the language (the whole sheet says that one).
    func draftingNote(for language: CueLanguage) -> String? {
        guard writer.drafting(in: language).cause?.isLanguage == true else { return nil }
        return String(localized: "Apple Intelligence can’t draft in it yet")
    }

    /// The tools of Improve: "In my voice" first, then the format's own. Every touch-up is Apple Intelligence's, on the iPhone or Private Cloud
    /// Compute, whoever wrote the script (owner, 01/11/2026: Ultra AI writes, it never touches up, so a script costs one writing); where it can't
    /// draft this script, only the tools that need no model are there. "3 new hooks" is never one of them: the tools row's Hook opens the same
    /// sheet, and the tip that the hook runs long opens it from here.
    var tools: [ScriptTool] {
        ([.inMyVoice] + structure.tools).filter { $0 != .newHooks && (canDraft || !$0.needsLanguageModel) }
    }

    /// Improve has something to offer: a tool, or the tip that the hook runs long.
    var offersImprove: Bool { !tools.isEmpty || hookOverrun != nil }

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

    /// The hook alone is replaced (`ScriptHook`): the rest of its paragraph, a disclosure and the cues around it stay, and Undo puts it back.
    func replaceHook(with hook: String) {
        guard let script else { return }
        let message = String(localized: "Hook replaced · ~\(DurationText.short(ReadTime.seconds(for: hook, language: paceLanguage)))")
        adopt(ScriptHook.replacing(in: script.text, with: hook), message: message)
    }

    /// "Pick a new hook": the model writes three for this script when it can; otherwise the
    /// format's own ideas.
    func openHooks() async {
        sheet = .hooks
        guard generatedHooks == nil else { return }
        await loadHooks()
    }

    func showMoreHooks() async {
        if canDraft {
            await loadHooks()
        } else {
            hookRotation += 1
        }
    }

    private func loadHooks() async {
        guard !isLoadingHooks, canDraft else { return }
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

    /// "I checked": the creator reviewed the claims of this version (recorded with the date, `FactReview`). An AI rewrite that changes the
    /// words brings the reminder back.
    func markFactChecked() {
        library.markFactChecked(scriptID)
        toast.show(String(localized: "Claims reviewed for this version"))
    }

    /// A copy the AI made of a script whose claims need (or needed) checking needs checking too.
    private var copiesNeedFactCheck: Bool { script.map { $0.factCheck || $0.factReview != nil } ?? false }

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
                message: String(localized: "Disclosure added up front"), kind: .done
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
    /// from the old ones). The toast says what happened (Cue's ★ for its own writing), and its Undo puts the old words back.
    private func adopt(_ text: String, message: String, kind: ToastKind = .cue, about title: String? = nil) {
        guard let script else { return }
        let before = (text: script.text, version: script.version)
        let bumpsVersion = !scriptTakes.isEmpty
        library.update(scriptID) { script in
            script.text = text
            if bumpsVersion { script.version += 1 }
        }
        syncPage()
        sheet = nil
        let undo = ToastAction(title: String(localized: "Undo")) { [weak self] in
            guard let self else { return }
            library.update(scriptID) { script in
                script.text = before.text
                script.version = before.version
            }
            library.clearFactCheckIfReviewed(scriptID)
            syncPage()
            toast.show(String(localized: "Undone"))
        }
        // A tool's rewrite took a while: it never takes an Undo's place, and names the script once the page is gone.
        if let title {
            sayResult(message, kind: kind, action: undo, about: title)
        } else {
            toast.show(message, kind: kind, duration: .seconds(4), action: undo)
        }
    }

    private func rewrite(with tool: ScriptTool) async {
        guard let title = script?.displayTitle else { return }
        if let reason = drafting.reason {
            toast.show(reason, kind: .problem)
            return
        }
        let before = workingText
        guard ReadTime.wordCount(in: before) > 0 else {
            toast.show(String(localized: "Write a few lines. Cue builds on them."), kind: .problem)
            return
        }
        runningTool = tool
        defer { runningTool = nil }
        do {
            let result = try await writer.rewriteReported(before, with: tool, context: rewriteContext)
            let notice = RewriteNotice.after(
                tool, before: before, result: result, done: doneMessage(for: tool), idealRange: preset.idealRange, language: paceLanguage
            )
            if notice.changesScript {
                // What the AI wrote changes the claims: whatever was checked before is to be checked again (decision 9).
                adopt(result.text, message: notice.message, about: title)
                library.flagForFactCheckAfterRewrite(scriptID)
            } else {
                sheet = nil
                sayResult(notice.message, kind: notice.kind, action: notice.kind == .problem ? retry { await $0.run(tool) } : nil, about: title)
            }
        } catch {
            sayFailure(error, about: title) { await $0.run(tool) }
        }
    }

    private func translate(into language: CueLanguage) async {
        guard let script else { return }
        let title = script.displayTitle
        // Apple Intelligence itself is told here; a language of the pair it can't take is named by the translation (both languages).
        if let reason = writer.drafting(in: []).reason {
            toast.show(reason, kind: .problem)
            return
        }
        guard ReadTime.wordCount(in: workingText) > 0 else {
            toast.show(String(localized: "Write a few lines. Cue builds on them."), kind: .problem)
            return
        }
        runningTool = .translate
        defer { runningTool = nil }
        do {
            var context = rewriteContext
            context.language = language
            let result = try await writer.rewriteReported(workingText, with: .translate, context: context)
            guard !result.isUntouched else {
                sayResult(String(localized: "Couldn’t draft it"), kind: .problem, action: retry { await $0.run(.translate, language: language) }, about: title)
                return
            }
            // A translation is a new script in the new language; the original stays as written. What the AI writes is a draft until the
            // creator says it is ready (the owner's call, 20/10/2026), and an Ultra AI draft stays one in any language.
            library.create(
                title: String(localized: "\(script.displayTitle) (\(language.localizedName))"),
                text: result.text, platform: script.platform, type: script.type, folder: script.folder,
                factCheck: copiesNeedFactCheck, language: language, isFinished: false, draftedBy: script.draftedBy
            )
            sheet = nil
            // Not written (a full iPhone): the app says so (`RootView`), never that it was saved.
            guard !library.saveFailed else { return }
            var message = String(localized: "\(language.localizedName) version saved")
            if result.leftAsWritten > 0 {
                message += " · " + String(localized: "\(result.leftAsWritten) of \(result.parts) parts left as written")
            }
            sayResult(message, kind: .cue, about: title, away: Self.versionSaved(language.localizedName, of: title))
        } catch {
            sayFailure(error, about: title) { await $0.run(.translate, language: language) }
        }
    }

    // MARK: - Versions

    /// "Make a version for…": a copy fitted to another platform's length and pace, with its preset.
    func makeVersion(for platform: Platform) async {
        guard let script, versionInProgress == nil else { return }
        // Told before "Drafting the … version…", not after it.
        if let reason = drafting.reason {
            toast.show(reason, kind: .problem)
            return
        }
        versionInProgress = platform
        let title = script.displayTitle
        // The ring turns while the version is written; what came of it takes its place, and a stop lets it go.
        let work = toast.showWorking(String(localized: "Drafting the \(platform.label) version…"))
        defer {
            versionInProgress = nil
            toast.endWorking(work)
        }
        do {
            var context = rewriteContext
            context.platform = platform
            let range = rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals).idealRange
            context.idealRange = range
            // The words on the page, the last one typed included (saved a second later).
            let result = try await writer.rewriteReported(workingText, with: .fitToTime, context: context)
            library.create(
                title: String(localized: "\(script.displayTitle) (\(platform.label))"),
                text: result.text, platform: platform, type: script.type, folder: script.folder,
                factCheck: copiesNeedFactCheck, language: script.language, isFinished: false, draftedBy: script.draftedBy
            )
            guard !library.saveFailed else { return }
            var message = String(localized: "\(platform.label) version saved")
            // The version is the script as the platform's length asks it, or says how far it got.
            if let length = RewriteNotice.lengthNote(words: ReadTime.wordCount(in: result.text), idealRange: range, language: script.paceLanguage) {
                message += " · " + length
            }
            sayResult(message, kind: .cue, ending: work, about: title, away: Self.versionSaved(platform.label, of: title))
        } catch {
            sayFailure(error, ending: work, about: title) { await $0.makeVersion(for: platform) }
        }
    }

    private func doneMessage(for tool: ScriptTool) -> String {
        switch tool {
        case .fitToTime:
            let range = DurationText.range(preset.idealRange)
            return String(localized: "Fitted to \(range)")
        case .inMyVoice:
            let sounds = profile.profile.sounds.prefix(2).map { $0.label.lowercased() }.joined(separator: ", ")
            return String(localized: "In your voice · \(sounds)")
        case .moreEnergy: return String(localized: "More energy")
        case .fixGrammar: return String(localized: "Grammar fixed")
        case .strongerCTA: return String(localized: "Stronger call to action")
        case .moreHuman: return String(localized: "More natural")
        case .lessDefensive: return String(localized: "Removed defensive lines")
        case .shorterAndDirect: return String(localized: "Shorter")
        case .newHooks, .addDisclosure, .translate: return String(localized: "Done")
        }
    }

    // MARK: - Library actions

    func duplicate() {
        library.duplicate([scriptID])
        // Not written (a full iPhone): the app says so (`RootView`), never that it was saved.
        guard !library.saveFailed else { return }
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
                toast.show(String(localized: "That folder already exists"), kind: .problem)
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
