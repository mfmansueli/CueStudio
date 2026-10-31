//
//  IdeaLibrary.swift
//  Cue Studio
//

import Foundation

/// The ideas the app holds for each first-flight topic, in the interface language (`IdeaLibraryPack`): about forty a topic, after the handwritten
/// starters (`ThemeCatalog`). For a creator without Apple Intelligence they are what the card and Find inspiration offer; with it, what comes before
/// the model's first ideas. Read once, from the bundle, for the language the app runs in; a language without a pack has the starters alone.
nonisolated enum IdeaLibrary {
    static func resourceName(for localization: String) -> String { "IdeaLibrary-\(localization)" }

    /// The pack of the language the app runs in.
    static let current: IdeaLibraryPack? = Bundle.main.preferredLocalizations.first.flatMap { load($0) }

    static func load(_ localization: String, bundle: Bundle = .main) -> IdeaLibraryPack? {
        guard let url = bundle.url(forResource: resourceName(for: localization), withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(IdeaLibraryPack.self, from: data)
    }

    /// The pack's ideas about `niche`, in the pack's order (its angles in turn), as starters: whole briefs without the model's angle mark, so the
    /// card treats them as starters (shown once each).
    static func ideas(for niche: Niche, in pack: IdeaLibraryPack? = current) -> [ThemeIdea] {
        guard let pack else { return [] }
        let language = Locale.Language(identifier: pack.language).minimalIdentifier
        return pack.ideas.compactMap { entry -> ThemeIdea? in
            guard entry.topic == niche.rawValue, let angle = IdeaAngle(rawValue: entry.angle) else { return nil }
            let length: ScriptLength = [.story, .dayInLife, .comparison].contains(angle) ? .minutes2 : .minute1
            var idea = ThemeIdea(title: entry.title, kind: angle.kind, length: length, niche: niche)
            idea.brief = IdeaBrief(
                subject: entry.title, angle: entry.pointOfView, openingLine: entry.openingLine, language: language, angleKind: angle.rawValue,
                topicKey: niche.rawValue, topic: niche.promptName
            )
            return idea
        }
    }
}
