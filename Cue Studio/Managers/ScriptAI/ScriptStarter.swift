//
//  ScriptStarter.swift
//  Cue Studio
//

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

    init(
        library: ScriptLibraryService, rules: PlatformRulesService, profile: CreatorProfileService,
        languages: LanguageService, presentation: PresentationService, ideaDraft: IdeaDraftService
    ) {
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
            interfaceLanguage: languages.interfaceLanguage
        )
    }

    /// The platform the card's chip shows: the creator's choice for this idea, or their default.
    var platform: Platform { ideaDraft.platform ?? factory.defaultPlatform }

    /// Writes `idea` (the card's own text when nil), for the platform and format chosen on the card.
    /// - Parameter comment: the audience comment the script answers, kept on the script.
    @discardableResult
    func write(idea: String? = nil, length: ScriptLength? = nil, comment: ScriptComment? = nil, platform: Platform? = nil) -> UUID? {
        guard let text = idea ?? ideaDraft.submission, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let request = factory.request(
            idea: text, platform: platform ?? ideaDraft.platform, format: ideaDraft.format, length: length ?? ideaDraft.length,
            brand: ideaDraft.brand
        )
        let script = library.create(
            title: "", text: "", platform: request.platform, type: request.format, language: languages.scriptLanguage, comment: comment
        )
        presentation.openScript(script.id, writing: request)
        return script.id
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
