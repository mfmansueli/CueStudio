//
//  ScriptStarter.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Sends an idea to the script page: a new empty script is opened and Apple Intelligence writes
/// into it, so the creator watches the words arrive instead of waiting on a sheet. The card's
/// arrow and the ↑ on an idea in "Need an idea?" both come here.
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
    private let sky: SkyMemory
    private let writer: ScriptWriting
    private let toast: ToastService

    init(
        library: ScriptLibraryService, rules: PlatformRulesService, profile: CreatorProfileService,
        languages: LanguageService, presentation: PresentationService, ideaDraft: IdeaDraftService,
        transition: IdeaTransitionService, sky: SkyMemory, writer: ScriptWriting, toast: ToastService
    ) {
        self.writer = writer
        self.toast = toast
        self.transition = transition
        self.sky = sky
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

    /// Writes `idea` (the card's own text when nil), for the platform and format chosen on the card. The idea's star is the transition
    /// (`IdeaTransitionService`): it rises from `origin` (the arrow; the bottom of the screen when nil) while the page is opened under it
    /// and the AI writes.
    /// - Parameter comment: the audience comment the script answers, kept on the script.
    /// - Parameter whenWritten: runs when the idea has become a script (not when it was cancelled or failed).
    @discardableResult
    func write(
        idea: String? = nil, length: ScriptLength? = nil, comment: ScriptComment? = nil, platform: Platform? = nil, from origin: CGPoint? = nil,
        whenWritten: ((UUID) -> Void)? = nil
    ) -> UUID? {
        guard let text = idea ?? ideaDraft.submission, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let request = factory.request(
            idea: text, platform: platform ?? ideaDraft.platform, format: ideaDraft.format, length: length ?? ideaDraft.length,
            brand: ideaDraft.brand
        )
        // A language Apple Intelligence doesn't write is told now, not after three seconds of star: the idea
        // becomes a blank draft to write by hand, the way it does without Apple Intelligence.
        if let failure = writer.writingFailure(in: request.language.map { [$0.locale.language] } ?? []) {
            toast.show(failure.error().localizedDescription)
            return writeByHand(idea: text, format: request.format, comment: comment)
        }
        let script = library.create(
            title: "", text: "", platform: request.platform, type: request.format, language: languages.scriptLanguage, comment: comment
        )
        presentation.openScript(script.id, writing: request)
        let scriptID = script.id
        transition.begin(
            from: origin ?? .zero, idea: text, platformName: request.platform.label,
            abort: { [weak self] in self?.abort(scriptID) },
            arrive: { [weak self] in
                self?.sky.addStar()
                whenWritten?(scriptID)
            }
        )
        return script.id
    }

    /// Cancel, or an error while the star is on screen: no script is created, and the idea is still in the field.
    private func abort(_ scriptID: UUID) {
        presentation.scriptsPath = []
        library.delete([scriptID])
    }

    /// With no Apple Intelligence, "Write it": the idea becomes the title of a blank draft, opened to write in (04 · F2).
    @discardableResult
    func writeByHand(idea: String? = nil, format: ScriptType? = nil, comment: ScriptComment? = nil) -> UUID? {
        let title = (idea ?? ideaDraft.submission ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let script = library.create(
            title: title, text: "", platform: comment?.platform ?? platform, type: format ?? ideaDraft.format,
            language: languages.scriptLanguage, comment: comment, isFinished: false
        )
        presentation.openScript(script.id, editing: true)
        ideaDraft.clear()
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
