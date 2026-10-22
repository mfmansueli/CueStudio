//
//  ScriptStarter.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Sends an idea to the script page: a new empty script is opened and Apple Intelligence writes
/// into it, so the creator watches the words arrive instead of waiting on a sheet. The card's
/// arrow and "Draft it now" in Find inspiration both come here.
@MainActor
@Observable
final class ScriptStarter {
    private let library: ScriptLibraryService
    private let rules: PlatformRulesService
    private let profile: CreatorProfileService
    private let languages: LanguageService
    private let presentation: PresentationService
    private let ideaDraft: IdeaDraftService
    private let transition: IdeaTransitionService
    private let writer: ScriptWriting
    private let toast: ToastService
    /// Told when a script was written from an idea of Find inspiration's (what of its brief the creator's text still said): the strongest sign of
    /// what they want, which the next ideas lean to (`IdeaSuggestionService.generated(from:)`). Set by `AppServices`, so no screen has to.
    var briefWritten: ((IdeaBrief) -> Void)?
    /// Keeps an audience comment whose reply couldn't be drafted after all (Apple Intelligence changed while the star rose): the sheet it was
    /// read in is gone, so it waits in the Logbook. Set by `AppServices`.
    var keepsComment: ((ScriptComment) -> Void)?

    init(
        library: ScriptLibraryService, rules: PlatformRulesService, profile: CreatorProfileService,
        languages: LanguageService, presentation: PresentationService, ideaDraft: IdeaDraftService,
        transition: IdeaTransitionService, writer: ScriptWriting, toast: ToastService
    ) {
        self.writer = writer
        self.toast = toast
        self.transition = transition
        self.library = library
        self.rules = rules
        self.profile = profile
        self.languages = languages
        self.presentation = presentation
        self.ideaDraft = ideaDraft
    }

    var factory: ScriptRequestFactory {
        ScriptRequestFactory(
            rules: rules, profile: profile, scriptLanguage: languages.scriptLanguage,
            interfaceLanguage: languages.interfaceLanguage, preferredLanguages: languages.systemLanguages
        )
    }

    /// The platform the card's chip shows: the creator's choice for this idea, or their default.
    var platform: Platform { ideaDraft.platform ?? factory.defaultPlatform }

    /// Whether the dock's ideas can be drafted, told before anything is typed: in the Script Language when one is set. On Auto-detect the
    /// language is the idea's own, known only when it is sent (`write`), so only what doesn't depend on it is told.
    var dockDrafting: DraftingAvailability { writer.drafting(in: languages.scriptLanguage) }

    /// Whether `text` (an answered comment, the dock's idea) can be drafted, before it is sent: in the language it would be drafted in when
    /// that is already known (the Script Language, or the text's own); otherwise only what doesn't depend on a language.
    func drafting(before text: String?) -> DraftingAvailability {
        writer.drafting(in: factory.knownLanguage(for: text ?? ""))
    }

    /// Writes `idea` (the card's own text when nil), for the platform and format chosen on the card. The idea's star is the transition
    /// (`IdeaTransitionService`): it rises from `origin` (the arrow; the bottom of the screen when nil) while the page is opened under it
    /// and the AI writes.
    /// - Parameter comment: the audience comment the script answers, kept on the script.
    /// - Parameter brief: the inspiration `idea` came from (the card's own brief when the card's text is written); only what the text still
    ///   says of it reaches the model.
    /// - Parameter whenWritten: runs when the idea has become a script (not when it was cancelled or failed).
    @discardableResult
    func write(
        idea: String? = nil, length: ScriptLength? = nil, comment: ScriptComment? = nil, platform: Platform? = nil, brief: IdeaBrief? = nil,
        from origin: CGPoint? = nil, whenWritten: ((UUID) -> Void)? = nil
    ) -> UUID? {
        guard let text = idea ?? ideaDraft.submission, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let request = factory.request(
            idea: text, platform: platform ?? ideaDraft.platform, format: ideaDraft.format, length: length ?? ideaDraft.length,
            brand: ideaDraft.brand, brief: brief ?? (idea == nil ? ideaDraft.brief : nil), languageText: comment?.text
        )
        // What Apple Intelligence can't draft (in the request's own language) is told now, not after three seconds of star, and nothing is
        // opened: the idea stays where it was, and "Write it" makes it a draft to write by hand only when the creator asks.
        let asked = request.language.map { [$0.locale.language] } ?? []
        if case .unavailable(let cause) = writer.drafting(in: asked) {
            if let failure = writer.writingFailure(in: asked) {
                AIFailureReport.note(failure, operation: "script", route: nil, language: request.language?.locale.identifier, seconds: 0, isFinal: true)
            }
            toast.show(cause.reason, action: ToastAction(title: String(localized: "Write it")) { [weak self] in
                guard let self else { return }
                // The dock's own idea leaves the dock as it becomes the draft; an idea from elsewhere leaves the creator's draft alone.
                let id = idea == nil ? writeByHand(idea: text, format: request.format, comment: comment)
                    : openBlankDraft(title: text, format: request.format, comment: comment)
                if let id { whenWritten?(id) }
            })
            return nil
        }
        let script = library.create(
            title: "", text: "", platform: request.platform, type: request.format, language: languages.scriptLanguage, comment: comment
        )
        presentation.openScript(script.id, writing: request)
        let scriptID = script.id
        transition.begin(
            from: origin ?? .zero, idea: text, platformName: request.platform.label,
            abort: { [weak self] in self?.abort(scriptID, keeping: comment) },
            arrive: { [weak self] in
                if let brief = request.brief { self?.briefWritten?(brief) }
                whenWritten?(scriptID)
            }
        )
        return script.id
    }

    /// Cancel, or an error while the star is on screen: no script is created, and the idea is still in the field. After an error, an
    /// answered comment (whose sheet is gone) is kept in the Logbook.
    private func abort(_ scriptID: UUID, keeping comment: ScriptComment?) {
        presentation.scriptsPath = []
        library.delete([scriptID])
        if transition.leftBecauseOfError, let comment { keepsComment?(comment) }
    }

    /// With no Apple Intelligence, "Write it": the idea becomes the title of a blank draft, opened to write in (04 · F2).
    @discardableResult
    func writeByHand(idea: String? = nil, format: ScriptType? = nil, comment: ScriptComment? = nil) -> UUID? {
        let id = openBlankDraft(title: idea ?? ideaDraft.submission ?? "", format: format, comment: comment)
        ideaDraft.clear()
        return id
    }

    /// A blank draft named `title`, opened to write in; the dock's own draft stays.
    @discardableResult
    private func openBlankDraft(title: String, format: ScriptType?, comment: ScriptComment?) -> UUID {
        let script = library.create(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines), text: "", platform: comment?.platform ?? platform,
            type: format ?? ideaDraft.format, language: languages.scriptLanguage, comment: comment, isFinished: false
        )
        presentation.openScript(script.id, editing: true)
        return script.id
    }

    /// "Start from a format": a blank draft with the format's sections, to write in.
    @discardableResult
    func startFromFormat(_ choice: FormatChoice) -> UUID {
        let script = library.create(
            title: "", text: "", platform: platform, type: choice.scriptType, language: languages.scriptLanguage, isFinished: false
        )
        presentation.openScript(script.id, editing: true)
        return script.id
    }
}
