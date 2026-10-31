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
    /// Ultra AI, where this build offers it; nil (tests, previews) offers none.
    private let ultra: UltraScriptWriting?
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
        transition: IdeaTransitionService, writer: ScriptWriting, ultra: UltraScriptWriting? = nil, toast: ToastService
    ) {
        self.writer = writer
        self.ultra = ultra
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
    /// language is the idea's own, known only when it is sent (`write`), so only what doesn't depend on it is told. With Ultra chosen (and
    /// allowed) Apple Intelligence's availability doesn't matter: Gemini writes it.
    var dockDrafting: DraftingAvailability { writesWithUltra ? .available : appleDrafting }

    /// Whether Apple Intelligence itself can draft in the Script Language, whoever the dock's chip picked.
    var appleDrafting: DraftingAvailability { writer.drafting(in: languages.scriptLanguage) }

    // MARK: - Ultra

    /// Ultra is offered on this iPhone (Debug, with the lab set up): the dock shows its chip.
    var offersUltra: Bool { ultra?.isAvailable == true }

    /// The creator allowed Google processing for Ultra.
    var ultraAllowed: Bool { ultra?.isReady == true }

    /// The dock's next idea goes to Ultra: the creator picked it and allowed Google processing.
    var writesWithUltra: Bool { ideaDraft.engine == .ultra && ultraAllowed }

    /// Ultra AI scripts the creator may still write; nil when nothing is counted.
    var ultraScriptsLeft: Int? { ultra?.scriptsLeft }

    /// No Ultra AI script is left to write.
    var ultraUsedUp: Bool { ultraScriptsLeft == 0 }

    /// The dock's writer chip: Ultra only once permission is there (`UltraConsentSheet` asks first) and with scripts left; Apple Intelligence any
    /// time. The pick stays until the creator changes it (`IdeaDraftService.engine`).
    func choose(_ engine: ScriptEngine) {
        ideaDraft.engine = engine == .ultra && (!ultraAllowed || ultraUsedUp) ? .apple : engine
    }

    /// The creator's Ultra AI scripts are used up: on the free plan Cue Pro is offered (it adds its monthly scripts); on Pro the toast says when
    /// more come. The next idea goes to Apple Intelligence.
    func showUltraUsedUp() {
        ideaDraft.engine = .apple
        switch ultra?.membership {
        case .paid:
            toast.show(String(localized: "This month’s Ultra AI scripts are used · More next month"), kind: .problem)
        case .free, nil:
            presentation.paywall = .ultra
        }
    }

    /// What Ultra would send for the dock's idea as it stands (or a placeholder for it), with the dock's choices and My Cue Voice: My Cue
    /// Voice's "What Cue sends" shows the very text the calls carry.
    func ultraPreview() -> UltraPayload {
        let typed = ideaDraft.submission?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = typed.isEmpty ? String(localized: "[Your idea, exactly as you type it]") : typed
        var request = factory.request(
            idea: text, platform: ideaDraft.platform, format: ideaDraft.format, length: ideaDraft.length, brand: ideaDraft.brand,
            brief: ideaDraft.brief, languageText: nil, formatChoice: ideaDraft.formatChoice
        )
        request.engine = .ultra
        return UltraPayload(request)
    }

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
    /// - Parameter engine: who writes it, when the caller asked for one (Find inspiration's "Draft with Ultra"); nil follows the dock's chip.
    /// - Parameter whenWritten: runs when the idea has become a script (not when it was cancelled or failed).
    @discardableResult
    func write(
        idea: String? = nil, length: ScriptLength? = nil, comment: ScriptComment? = nil, platform: Platform? = nil, brief: IdeaBrief? = nil,
        engine: ScriptEngine? = nil, from origin: CGPoint? = nil, whenWritten: ((UUID) -> Void)? = nil
    ) -> UUID? {
        guard let text = idea ?? ideaDraft.submission, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var request = IdeaSendTimeline.measure("Idea request") {
            factory.request(
                idea: text, platform: platform ?? ideaDraft.platform, format: ideaDraft.format, length: length ?? ideaDraft.length,
                brand: ideaDraft.brand, brief: brief ?? (idea == nil ? ideaDraft.brief : nil), languageText: comment?.text,
                formatChoice: ideaDraft.formatChoice
            )
        }
        // Ultra only when it was picked and is still allowed: never as a silent stand-in for Apple Intelligence. An answered comment stays with
        // Apple Intelligence (the dock's choice is for the dock's ideas and Find inspiration's).
        if (engine ?? ideaDraft.engine) == .ultra, comment == nil {
            guard ultraAllowed else {
                ideaDraft.engine = .apple
                toast.show(UltraError.consentRequired.localizedDescription, kind: .problem)
                return nil
            }
            guard !ultraUsedUp else {
                showUltraUsedUp()
                return nil
            }
            request.engine = .ultra
        }
        // What Apple Intelligence can't draft (in the request's own language) is told now, not after three seconds of star, and nothing is
        // opened: the idea stays where it was, and "Write it" makes it a draft to write by hand only when the creator asks.
        let asked = request.language.map { [$0.locale.language] } ?? []
        if request.engine == .apple,
           case .unavailable(let cause) = IdeaSendTimeline.measure("Language check", { writer.drafting(in: asked) }) {
            if let failure = writer.writingFailure(in: asked) {
                AIFailureReport.note(failure, operation: "script", route: nil, language: request.language?.locale.identifier, seconds: 0, isFinal: true)
            }
            toast.show(cause.reason, kind: .problem, action: ToastAction(title: String(localized: "Write it")) { [weak self] in
                guard let self else { return }
                // The dock's own idea leaves the dock as it becomes the draft; an idea from elsewhere leaves the creator's draft alone.
                let id = idea == nil ? writeByHand(idea: text, format: request.format, comment: comment)
                    : openBlankDraft(title: text, format: request.format, comment: comment)
                if let id { whenWritten?(id) }
            })
            return nil
        }
        let script = IdeaSendTimeline.measure("Script created") {
            library.create(
                title: "", text: "", platform: request.platform, type: request.format, language: languages.scriptLanguage, comment: comment
            )
        }
        let scriptID = script.id
        // The star holds the app still as it was at the tap (`IdeaTransitionService.showsBackdrop`), so the page opens under it at once,
        // without a push to watch (nor its frames to pay for), and Apple Intelligence starts writing into it right away.
        transition.begin(
            from: origin ?? .zero, idea: text, platformName: request.platform.label, engine: request.engine,
            abort: { [weak self] in
                self?.abort(scriptID, keeping: comment) { [weak self] in
                    // The same idea (the field's own when it came from the dock: it is still there), the same choices, a new star.
                    self?.write(
                        idea: idea, length: length, comment: comment, platform: platform, brief: brief, engine: engine, whenWritten: whenWritten
                    )
                }
            },
            arrive: { [weak self] in
                if let brief = request.brief { self?.briefWritten?(brief) }
                // The writer stays the creator's pick for the next idea. One Apple Intelligence wrote counts towards the invitation to try Ultra.
                if request.engine == .apple { self?.ultra?.noteAIUse() }
                whenWritten?(scriptID)
            }
        )
        IdeaSendTimeline.measure("Page opened") { presentation.openScript(scriptID, writing: request, animated: false) }
        return scriptID
    }

    /// Cancel, or an error while the star is on screen: no script is created, and the idea is still in the field. After an error, the toast
    /// says why, with "Try again" (`again`) when asking again may work; an answered comment (whose sheet is gone) is kept in the Logbook
    /// instead, where it is written from again.
    private func abort(_ scriptID: UUID, keeping comment: ScriptComment?, again: @escaping @MainActor () -> Void) {
        // Under the cover: the live app comes back already on Scripts.
        presentation.showScriptsList(animated: false)
        library.delete([scriptID])
        guard transition.leftBecauseOfError else { return }
        if let comment { keepsComment?(comment) }
        guard let failure = transition.failure else { return }
        let retry = failure.canRetry && comment == nil
        toast.showResult(failure.reason, kind: .problem, action: retry ? ToastAction(title: String(localized: "Try again"), perform: again) : nil)
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
