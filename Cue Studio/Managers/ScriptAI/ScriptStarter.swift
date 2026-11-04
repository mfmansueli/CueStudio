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
    /// Keeps an audience comment in the Logbook before its reply is asked for, so a Cancel, a failure or Cue closing never loses it (its sheet
    /// is gone): the note it is in, and whether it was made now (the same words already waiting there are that note, never a copy). Nil when it
    /// couldn't be kept. Set by `AppServices`.
    var keepsComment: ((ScriptComment) -> (note: UUID, isNew: Bool)?)?
    /// The reply is written: the note made for it goes (the comment is on the script), one that was already waiting is shaped into it. Set by
    /// `AppServices`.
    var commentAnswered: ((_ note: (note: UUID, isNew: Bool), _ scriptID: UUID) -> Void)?

    init(
        library: ScriptLibraryService, profile: CreatorProfileService,
        languages: LanguageService, presentation: PresentationService, ideaDraft: IdeaDraftService,
        transition: IdeaTransitionService, writer: ScriptWriting, ultra: UltraScriptWriting? = nil, toast: ToastService
    ) {
        self.writer = writer
        self.ultra = ultra
        self.toast = toast
        self.transition = transition
        self.library = library
        self.profile = profile
        self.languages = languages
        self.presentation = presentation
        self.ideaDraft = ideaDraft
    }

    var factory: ScriptRequestFactory {
        ScriptRequestFactory(
            profile: profile, scriptLanguage: languages.scriptLanguage,
            interfaceLanguage: languages.interfaceLanguage, preferredLanguages: languages.systemLanguages
        )
    }

    /// The platform the card's chip shows: the creator's choice for this idea, or their default.
    var platform: Platform { ideaDraft.platform ?? factory.defaultPlatform }

    /// The creator's own platform (Profile): what a script started away from the dock is for, unless its flow says another.
    var defaultPlatform: Platform { factory.defaultPlatform }

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
        let request = factory.request(
            idea: text, platform: ideaDraft.platform, format: ideaDraft.format, length: ideaDraft.length, brand: ideaDraft.brand,
            brief: ideaDraft.brief, languageText: nil, formatChoice: ideaDraft.formatChoice, engine: .ultra
        )
        return UltraPayload(request)
    }

    /// "Cue followed your idea over “Calls to action” in Avoid": what Cue offers by its label in the interface's language, what they typed as typed.
    static func followedIdea(over lifted: [String]) -> String {
        let names = lifted.map { stored in
            VoiceAvoidRule.rule(for: stored) == nil ? stored : String(localized: String.LocalizationValue(stored))
        }
        return String(localized: "Cue followed your idea over “\(names.formatted(.list(type: .and)))” in Avoid")
    }

    /// Whether `text` (an answered comment, the dock's idea) can be drafted, before it is sent: in the language it would be drafted in when
    /// that is already known (the Script Language, or the text's own); otherwise only what doesn't depend on a language.
    func drafting(before text: String?) -> DraftingAvailability {
        writer.drafting(in: factory.knownLanguage(for: text ?? ""))
    }

    /// Writes `idea` (the card's own text when nil). The idea's star is the transition (`IdeaTransitionService`): it rises from `origin` (the
    /// arrow; the bottom of the screen when nil) while the page is opened under it and the AI writes.
    ///
    /// The card's choices (platform, length, format, brand) are the dock's: they shape what is sent from it (`fromDock`: its own text, an idea
    /// on its card, its sponsored ad), read once here so changing them afterwards never changes a request under way, and they go back to the
    /// defaults only once that script is saved, if the dock is still as it was sent. An idea from elsewhere (Logbook, Find inspiration, a
    /// comment) is written with the creator's defaults and its flow's own choices, and leaves the dock as it is (A23).
    /// - Parameter comment: the audience comment the script answers, kept on the script.
    /// - Parameter brief: the inspiration `idea` came from (the card's own brief when the card's text is written); only what the text still
    ///   says of it reaches the model.
    /// - Parameter engine: who writes it, when the caller asked for one (Find inspiration's "Draft with Ultra"); nil follows the dock's chip.
    /// - Parameter fromDock: sent from the dock (its card's idea, its ad); nil means "when `idea` is nil", the field's own text.
    /// - Parameter whenWritten: runs when the idea has become a script (not when it was cancelled or failed).
    @discardableResult
    func write(
        idea: String? = nil, length: ScriptLength? = nil, comment: ScriptComment? = nil, platform: Platform? = nil, brief: IdeaBrief? = nil,
        engine: ScriptEngine? = nil, fromDock: Bool? = nil, from origin: CGPoint? = nil, whenWritten: ((UUID) -> Void)? = nil
    ) -> UUID? {
        guard let text = idea ?? ideaDraft.submission, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let fromDock = fromDock ?? (idea == nil)
        // The dock as it was sent: cleared once the script is saved only if it is still this (`clearDock`).
        let sentDock = fromDock ? ideaDraft.snapshot : nil
        // An audience comment is in the Logbook before anything is asked of it (A4): it is let go only once its reply is a script.
        let kept = comment.flatMap { keepsComment?($0) }
        // Ultra only when it was picked and is still allowed: never as a silent stand-in for Apple Intelligence. An answered comment stays with
        // Apple Intelligence (the dock's choice is for the dock's ideas and Find inspiration's).
        let writesWith: ScriptEngine = (engine ?? ideaDraft.engine) == .ultra && comment == nil ? .ultra : .apple
        if writesWith == .ultra {
            guard ultraAllowed else {
                ideaDraft.engine = .apple
                toast.show(UltraError.consentRequired.localizedDescription, kind: .problem)
                return nil
            }
            guard !ultraUsedUp else {
                showUltraUsedUp()
                return nil
            }
        }
        let request = IdeaSendTimeline.measure("Idea request") {
            factory.request(
                idea: text, platform: platform ?? (fromDock ? ideaDraft.platform : nil), format: fromDock ? ideaDraft.format : nil,
                length: length ?? (fromDock ? ideaDraft.length : .auto), brand: fromDock ? ideaDraft.brand : nil,
                brief: brief ?? (idea == nil ? ideaDraft.brief : nil), languageText: comment?.text,
                formatChoice: fromDock ? ideaDraft.formatChoice : nil, engine: writesWith
            )
        }
        // What Apple Intelligence can't draft (in the request's own language) is told now, not after three seconds of star, and nothing is
        // opened: the idea stays where it was, and "Write it" makes it a draft to write by hand only when the creator asks.
        let asked = request.language.map { [$0.locale.language] } ?? []
        if request.engine == .apple,
           case .unavailable(let cause) = IdeaSendTimeline.measure("Language check", { writer.drafting(in: asked) }) {
            if let failure = writer.writingFailure(in: asked) {
                AIFailureReport.note(failure, operation: "script", route: nil, language: request.language?.locale.identifier, seconds: 0, isFinal: true)
            }
            let reason = kept == nil ? cause.reason : cause.reason + " · " + Self.savedToLogbook
            toast.show(reason, kind: .problem, action: ToastAction(title: String(localized: "Write it")) { [weak self] in
                guard let self else { return }
                // The dock's own idea leaves the dock as it becomes the draft; an idea from elsewhere leaves the creator's draft alone.
                let id = openBlankDraft(title: text, format: request.format, comment: comment, fromDock: fromDock, brand: request.brand)
                if let sentDock { clearDock(sent: sentDock, ownText: idea == nil) }
                if let kept { commentAnswered?(kept, id) }
                whenWritten?(id)
            })
            return nil
        }
        // A "never" of their voice that this idea asks for in so many words: the idea wins, and the creator is told once the script is there.
        let lifted = VoiceConstraintChecker.lifted(by: request)
        // These catchphrases had their turn: the next script is offered the others (`CatchphraseRotation`).
        if request.voice.map({ !$0.phrases.isEmpty }) == true { factory.profile.advanceCatchphraseTurn() }
        let script = IdeaSendTimeline.measure("Script created") {
            library.create(
                title: "", text: "", platform: request.platform, type: request.format, language: languages.scriptLanguage, comment: comment,
                awaitsDraft: true, brand: request.brand
            )
        }
        let scriptID = script.id
        // The star holds the app still as it was at the tap (`IdeaTransitionService.showsBackdrop`), so the page opens under it at once,
        // without a push to watch (nor its frames to pay for), and Apple Intelligence starts writing into it right away.
        transition.begin(
            from: origin ?? .zero, idea: text, platformName: request.platform.label, engine: request.engine,
            abort: { [weak self] in
                self?.abort(scriptID, keeping: kept) { [weak self] in
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
                if let kept { self?.commentAnswered?(kept, scriptID) }
                // Saved by now (the page keeps the script before the star lets go): the dock it came from starts over.
                if let sentDock { self?.clearDock(sent: sentDock, ownText: idea == nil) }
                if !lifted.isEmpty { self?.toast.showResult(Self.followedIdea(over: lifted)) }
                whenWritten?(scriptID)
            }
        )
        IdeaSendTimeline.measure("Page opened") { presentation.openScript(scriptID, writing: request, animated: false) }
        return scriptID
    }

    /// Cancel, or an error while the star is on screen: no script is created, and the idea is still in the field. After an error, the toast
    /// says why, with "Try again" (`again`) when asking again may work. An answered comment (whose sheet is gone) stays in the Logbook, where
    /// it was kept before the star rose, and the toast says so: after a Cancel too (it gives up on that reply, not on the comment).
    private func abort(_ scriptID: UUID, keeping comment: (note: UUID, isNew: Bool)?, again: @escaping @MainActor () -> Void) {
        // Under the cover: the live app comes back already on Scripts.
        presentation.showScriptsList(animated: false)
        library.delete([scriptID])
        guard transition.leftBecauseOfError else {
            if comment != nil { toast.showResult(Self.savedToLogbook) }
            return
        }
        guard let failure = transition.failure else { return }
        let retry = failure.canRetry && comment == nil
        let reason = comment == nil ? failure.reason : failure.reason + " · " + Self.savedToLogbook
        toast.showResult(reason, kind: .problem, action: retry ? ToastAction(title: String(localized: "Try again"), perform: again) : nil)
    }

    private static var savedToLogbook: String { String(localized: "Saved to Logbook") }

    /// A script sent from the dock is saved: the dock starts over, unless the creator changed it meanwhile (that is a new idea, never wiped).
    /// An idea on its card (`ownText` false) leaves words typed in the field where they are.
    private func clearDock(sent: DockDraft, ownText: Bool) {
        guard ideaDraft.snapshot == sent, ownText || ideaDraft.isEmpty else { return }
        ideaDraft.clear()
    }

    /// With no Apple Intelligence, "Write it": the idea becomes the title of a blank draft, opened to write in (04 · F2). The dock's own idea
    /// (no `idea`) leaves the dock with it; one from elsewhere (a comment answered by hand, the Logbook) leaves what the creator was typing there.
    @discardableResult
    func writeByHand(idea: String? = nil, format: ScriptType? = nil, comment: ScriptComment? = nil) -> UUID? {
        let id = openBlankDraft(title: idea ?? ideaDraft.submission ?? "", format: format, comment: comment, fromDock: idea == nil)
        if idea == nil { ideaDraft.clear() }
        return id
    }

    /// A blank draft named `title`, opened to write in; the dock's own draft stays. The card's choices only for the dock's own idea.
    @discardableResult
    private func openBlankDraft(title: String, format: ScriptType?, comment: ScriptComment?, fromDock: Bool, brand: BrandBrief? = nil) -> UUID {
        newBlank(
            title: title, platform: comment?.platform ?? (fromDock ? platform : defaultPlatform),
            format: format ?? (fromDock ? ideaDraft.format : nil), comment: comment, brand: brand
        )
    }

    /// "Start from a format" (the + menu, not the dock): a blank draft with the format's sections, for the creator's own platform.
    @discardableResult
    /// - Parameter brand: the brief of a sponsored ad, kept with the draft for the tools that rewrite it later.
    func startFromFormat(_ choice: FormatChoice, platform: Platform? = nil, brand: BrandBrief? = nil) -> UUID {
        newBlank(platform: platform ?? defaultPlatform, format: choice.scriptType, brand: choice.scriptType == .ad ? brand : nil)
    }

    /// Every blank draft the creator writes in: in the Script Language, a draft (not ready to record), opened with the keyboard.
    @discardableResult
    func newBlank(
        title: String = "", platform: Platform, format: ScriptType? = nil, comment: ScriptComment? = nil, brand: BrandBrief? = nil
    ) -> UUID {
        let script = library.create(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines), text: "", platform: platform, type: format,
            language: languages.scriptLanguage, comment: comment, isFinished: false, brand: format == .ad ? brand : nil
        )
        presentation.openScript(script.id, editing: true)
        return script.id
    }
}
