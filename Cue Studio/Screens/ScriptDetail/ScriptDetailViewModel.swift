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
        case destination, hooks
        var id: String { rawValue }
    }

    let scriptID: UUID
    private(set) var isEditing = false
    var draftTitle = ""
    var draftText = ""
    var sheet: Sheet?
    var isNamingFolder = false
    var newFolderName = ""
    private(set) var runningTool: ScriptTool?
    /// Text before the last AI rewrite, for Undo.
    private(set) var undoText: String?
    private(set) var hookRotation = 0
    /// Hooks written by the model for this script; nil until asked, or without Apple Intelligence.
    private(set) var generatedHooks: [String]?
    private(set) var isLoadingHooks = false

    private var originalTitle = ""
    private var originalText = ""

    private let library: ScriptLibraryService
    private let takes: TakeLibraryService
    private let preferences: PreferencesService
    private let profile: CreatorProfileService
    private let rules: PlatformRulesService
    private let writer: ScriptWriting
    private let toast: ToastService

    init(
        scriptID: UUID,
        startsEditing: Bool = false,
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
        if startsEditing { startEditing() }
    }

    // MARK: - Reading

    var script: Script? { library.script(id: scriptID) }

    /// The draft while editing, the saved text otherwise.
    var workingText: String { isEditing ? draftText : (script?.text ?? "") }

    var structure: ScriptStructure { script?.structure ?? .generic }

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

    /// Shown while editing a script that already has takes.
    var versionNotice: String? {
        let count = scriptTakes.count
        guard isEditing, count > 0, let version = script?.version else { return nil }
        return count == 1
            ? String(localized: "Editing creates v\(version + 1) · your take stays linked to v\(version)")
            : String(localized: "Editing creates v\(version + 1) · your \(count) takes stay linked to v\(version)")
    }

    var isLanguageModelAvailable: Bool { writer.isLanguageModelAvailable }

    /// The tools above the keyboard: "In my voice" first, then the format's own.
    var tools: [ScriptTool] { [.inMyVoice] + structure.tools }

    private var rewriteContext: RewriteContext {
        RewriteContext(
            structure: structure,
            platform: script?.platform ?? .tiktok,
            idealRange: preset.idealRange,
            voice: profile.profile.voice
        )
    }

    // MARK: - Editing

    func startEditing() {
        guard let script else { return }
        draftTitle = script.title
        draftText = script.text
        originalTitle = script.title
        originalText = script.text
        undoText = nil
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
        undoText = nil
    }

    /// Saves the draft. Changing the words of a script that has takes creates a new version, so
    /// the takes stay tied to what was actually read.
    func finishEditing() {
        guard isEditing, let script else { return }
        isEditing = false
        undoText = nil
        let textChanged = draftText != originalText
        let titleChanged = draftTitle != originalTitle
        guard textChanged || titleChanged else { return }

        let takeCount = scriptTakes.count
        let bumpsVersion = textChanged && takeCount > 0
        let title = draftTitle
        let text = draftText
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
                ? String(localized: "Saved as v\(script.version + 1) — your take stays with v\(script.version)")
                : String(localized: "Saved as v\(script.version + 1) — \(takeCount) takes stay with v\(script.version)"))
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

    func run(_ tool: ScriptTool, language: TranslationLanguage? = nil) async {
        guard runningTool == nil else { return }
        switch tool {
        case .newHooks:
            await openHooks()
        case .addDisclosure:
            guard !ScriptTextEditing.hasDisclosure(workingText) else {
                toast.show(String(localized: "The disclosure is already up front"))
                return
            }
            undoText = draftText
            draftText = ScriptTextEditing.addingDisclosure(to: draftText)
            toast.show(String(localized: "Disclosure added up front"))
        case .translate:
            await translate(into: language ?? .spanish)
        default:
            await rewrite(with: tool)
        }
    }

    func undoRewrite() {
        guard let undoText else { return }
        draftText = undoText
        self.undoText = nil
    }

    private func rewrite(with tool: ScriptTool) async {
        guard script != nil else { return }
        guard writer.isLanguageModelAvailable else {
            toast.show(writer.unavailableReason ?? String(localized: "AI tools aren't available right now."))
            return
        }
        runningTool = tool
        defer { runningTool = nil }
        do {
            let before = draftText
            let rewritten = try await writer.rewrite(before, with: tool, context: rewriteContext)
            guard isEditing else { return }
            undoText = before
            draftText = rewritten
            toast.show(doneMessage(for: tool))
        } catch {
            toast.show(error.localizedDescription)
        }
    }

    private func translate(into language: TranslationLanguage) async {
        guard let script else { return }
        guard writer.isLanguageModelAvailable else {
            toast.show(writer.unavailableReason ?? String(localized: "AI tools aren't available right now."))
            return
        }
        runningTool = .translate
        defer { runningTool = nil }
        do {
            var context = rewriteContext
            context.language = language.promptName
            let translated = try await writer.rewrite(workingText, with: .translate, context: context)
            library.create(
                title: String(localized: "\(script.displayTitle) (\(language.label))"),
                text: translated, platform: script.platform, type: script.type, folder: script.folder
            )
            toast.show(String(localized: "\(language.label) version saved as a copy"))
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
