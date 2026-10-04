//
//  ScriptDetailViewModel.swift
//  Cue Studio
//

import Foundation

/// Reading and editing one script. Edits happen on a draft that is only written on Done, so Cancel
/// really cancels and versioning sees the whole change at once.
@MainActor
@Observable
final class ScriptDetailViewModel {
    enum Sheet: String, Identifiable {
        case destination, hooks, improve, details, scriptType
        var id: String { rawValue }
    }

    let scriptID: UUID
    private(set) var isEditing = false
    var draftTitle = ""
    /// The draft, a paragraph per entry (an empty one while the creator is about to type in it).
    /// `draftText` is the same thing as the text that gets saved.
    var draftParagraphs = [""]
    var sheet: Sheet?
    /// The single page (Draft | Shaped) the creator is on while not in the full editor.
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
    /// Where the editor is asked to put the caret (or to put the keyboard away).
    var focus: ParagraphFocus?
    /// The panel under the writing area in place of the keyboard.
    var tool: EditorTool?
    /// The paragraph with the caret, nil when none has it (the keyboard is away, or the title has it).
    var activeParagraph: Int?
    var isTitleFocused = false
    /// The last place the caret was, kept while a panel hides the keyboard so a cue goes where it was.
    var caret = ScriptParagraphs.Caret(index: 0, offset: 0)
    /// The paragraph to bring into view in read mode (a tap on a block of the Details sheet).
    var readScrollTarget: Int?
    var isNamingFolder = false
    var newFolderName = ""
    private(set) var runningTool: ScriptTool?
    /// Text before the last AI rewrite, for Undo.
    private(set) var undoText: String?
    private(set) var hookRotation = 0
    /// Hooks written by the model for this script; nil until asked, or without Apple Intelligence.
    private(set) var generatedHooks: [String]?
    private(set) var isLoadingHooks = false
    /// The platform a "Make a version for…" copy is being written for.
    private(set) var versionInProgress: Platform?

    private var originalTitle = ""
    private var originalText = ""

    let library: ScriptLibraryService
    let takes: TakeLibraryService
    let preferences: PreferencesService
    let profile: CreatorProfileService
    let rules: PlatformRulesService
    let writer: ScriptWriting
    let toast: ToastService

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
        toast: ToastService
    ) {
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

    /// The draft's text as it would be saved: paragraphs that say something, a blank line apart.
    var draftText: String {
        get { ScriptParagraphs.join(draftParagraphs) }
        set { draftParagraphs = ScriptParagraphs.split(newValue) }
    }

    /// The draft while editing, the saved text otherwise.
    var workingText: String {
        if isEditing { return draftText }
        return page.isLoaded ? (page.revealed ?? page.text) : (script?.text ?? "")
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
            voice: profile.profile.voice
        )
    }

    // MARK: - Editing

    /// Opens the editor with the caret at the end of paragraph `paragraph` (the first when the
    /// creator didn't tap one; the title for a script with nothing in it yet).
    func startEditing(atParagraph paragraph: Int? = nil) {
        commitPage()
        guard let script else { return }
        draftTitle = script.title
        draftParagraphs = ScriptParagraphs.split(script.text)
        originalTitle = script.title
        originalText = script.text
        undoText = nil
        tool = nil
        sheet = nil
        activeParagraph = nil
        isTitleFocused = false
        isEditing = true
        if script.title.isEmpty, script.isEmpty { return }
        let index = min(max(0, paragraph ?? 0), draftParagraphs.count - 1)
        caret = ScriptParagraphs.Caret(index: index, offset: draftParagraphs[index].utf16.count)
        focus = .at(index, offset: caret.offset)
    }

    /// "Discard changes": the draft goes and the script stays as it was.
    func cancelEditing() {
        syncPage()
        isEditing = false
        undoText = nil
        tool = nil
        focus = .keyboardAway
    }

    /// Saves the draft. Changing the words of a script that has takes creates a new version, so
    /// the takes stay tied to what was actually read.
    func finishEditing() {
        guard isEditing, let script else { return }
        defer { syncPage() }
        isEditing = false
        undoText = nil
        tool = nil
        focus = .keyboardAway
        // The words, not the way the lines were broken: a script is saved as it was when only the
        // spacing between its paragraphs differs.
        let textChanged = CueParser.paragraphs(in: draftText) != CueParser.paragraphs(in: originalText)
        let titleChanged = draftTitle != originalTitle
        guard textChanged || titleChanged else { return }

        let takeCount = scriptTakes.count
        let bumpsVersion = textChanged && takeCount > 0
        let title = draftTitle
        let text = textChanged ? draftText : originalText
        library.update(scriptID) { script in
            script.title = title
            script.text = text
            if bumpsVersion { script.version += 1 }
        }
        if titleChanged, let renamed = self.script {
            takes.renameScript(scriptID, to: renamed.displayTitle)
        }
        if bumpsVersion {
            toast.show(takeCount == 1
                ? String(localized: "Saved as v\(script.version + 1) · Take on v\(script.version)")
                : String(localized: "Saved as v\(script.version + 1) · \(takeCount) takes on v\(script.version)"))
        } else {
            toast.show(String(localized: "Saved"))
        }
    }

    // MARK: - Destination

    func setPlatform(_ platform: Platform) {
        library.update(scriptID) { $0.platform = platform }
        sheet = nil
        toast.show(String(localized: "Create for \(platform.destinationName)"))
    }

    // MARK: - Hooks

    func replaceHook(with hook: String) {
        if isEditing {
            draftText = ScriptTextEditing.replacingOpening(of: draftText, with: hook)
        } else {
            library.update(scriptID) { $0.text = ScriptTextEditing.replacingOpening(of: $0.text, with: hook) }
            syncPage()
        }
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
            closeToolPanel()
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
            await translate(into: language ?? .spanish)
        default:
            await rewrite(with: tool)
        }
    }

    /// Takes back the last change an AI tool made to the draft.
    func undoRewrite() {
        guard isEditing, let undoText else { return }
        draftText = undoText
        self.undoText = nil
        toast.show(String(localized: "Undone"))
    }

    /// What a tool wrote becomes the script's words: the draft while writing (the panel closes and
    /// the keyboard stays away, so the change is what's on screen), the saved text while reading.
    /// The toast says what happened and takes it back.
    private func adopt(_ text: String, message: String) {
        if isEditing {
            undoText = draftText
            draftText = text
            closeToolPanel()
            toast.show(message, duration: .seconds(4), action: ToastAction(title: String(localized: "Undo")) { [weak self] in
                self?.undoRewrite()
            })
        } else {
            saveWhileReading(text, message: message)
        }
    }

    /// An AI tool from "Improve script" on a script that isn't being edited: the words are saved
    /// at once (a new version when takes were made from the old ones) and Undo puts them back.
    private func saveWhileReading(_ text: String, message: String) {
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

    private func closeToolPanel() {
        tool = nil
        focus = .keyboardAway
    }

    private func rewrite(with tool: ScriptTool) async {
        guard script != nil else { return }
        guard writer.isLanguageModelAvailable else {
            toast.show(writer.unavailableReason ?? String(localized: "AI isn't available now"))
            return
        }
        runningTool = tool
        defer { runningTool = nil }
        do {
            let rewritten = try await writer.rewrite(workingText, with: tool, context: rewriteContext)
            adopt(rewritten, message: doneMessage(for: tool))
        } catch {
            toast.show(error.localizedDescription)
        }
    }

    private func translate(into language: CueLanguage) async {
        guard let script else { return }
        guard writer.isLanguageModelAvailable else {
            toast.show(writer.unavailableReason ?? String(localized: "AI isn't available now"))
            return
        }
        runningTool = .translate
        defer { runningTool = nil }
        do {
            var context = rewriteContext
            context.language = language
            let translated = try await writer.rewrite(workingText, with: .translate, context: context)
            // A translation is a new script in the new language; the original stays as written.
            library.create(
                title: String(localized: "\(script.displayTitle) (\(language.localizedName))"),
                text: translated, platform: script.platform, type: script.type, folder: script.folder,
                language: language
            )
            closeToolPanel()
            sheet = nil
            toast.show(String(localized: "\(language.localizedName) version saved"))
        } catch {
            toast.show(error.localizedDescription)
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
            context.idealRange = rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals).idealRange
            let text = try await writer.rewrite(script.text, with: .fitToTime, context: context)
            library.create(
                title: String(localized: "\(script.displayTitle) (\(platform.label))"),
                text: text, platform: platform, type: script.type, folder: script.folder,
                language: script.language
            )
            toast.show(String(localized: "\(platform.label) version saved"))
        } catch {
            toast.show(error.localizedDescription)
        }
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

    func delete() {
        library.delete([scriptID])
        toast.show(String(localized: "Script deleted"))
    }
}
