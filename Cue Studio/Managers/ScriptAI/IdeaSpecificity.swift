//
//  IdeaSpecificity.swift
//  Cue Studio
//

import Foundation

/// What makes a brief of the model's weak, read from its words alone: an angle that only says the title again (the angle is the claim the video
/// makes, not its subject), and a headline of stock words ("5 tips for…") with nothing particular in it. One weakness is a brief to show later; both
/// make it no idea at all (`isUnusable`), so a perspective that is merely unusual is never thrown away. Whether the opening line leads into the
/// title was tried and left out: on the baseline run it flagged 45 of 108 ideas, most for a synonym ("stretch" for "mobility").
nonisolated enum IdeaSpecificity {
    enum Weakness: String, Hashable, Sendable {
        case angleRestatesTitle, genericTitle
    }

    static func weaknesses(of idea: ThemeIdea) -> [Weakness] {
        guard let brief = idea.brief else { return [] }
        let title = IdeaSimilarity.words(in: idea.title)
        let angle = IdeaSimilarity.words(in: brief.angle)
        var found: [Weakness] = []
        // "Show", "explain": what every angle starts with is not what it adds.
        if !angle.isEmpty, angle.subtracting(title).subtracting(angleVerbs).count < 2 { found.append(.angleRestatesTitle) }
        let headline = Set(idea.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).split { !$0.isLetter }.map(String.init))
        let particular = title.subtracting(stockWords).filter { !$0.allSatisfy(\.isNumber) }
        if headline.contains(where: stockWords.contains), particular.count < 2 { found.append(.genericTitle) }
        return found
    }

    static func isUnusable(_ idea: ThemeIdea) -> Bool {
        weaknesses(of: idea).count >= 2
    }

    /// The verbs angles start with ("Show…", "Explain…"), folded.
    private static let angleVerbs: Set<String> = [
        "show", "share", "explain", "give", "talk", "tell", "list", "walk", "break", "reveal",
        "mostre", "mostra", "explique", "explica", "compartilhe", "fale", "conte", "de", "liste",
        "muestra", "comparte", "habla", "cuenta", "enumera",
    ]

    /// Words a headline is made of when it says nothing yet, folded like `IdeaSimilarity.words`, in the languages ideas are measured in most.
    private static let stockWords: Set<String> = [
        "tips", "things", "ways", "secrets", "hacks", "tricks", "ideas", "reasons", "facts", "everything", "need", "know", "best", "top", "ultimate",
        "dicas", "coisas", "formas", "segredos", "truques", "ideias", "motivos", "tudo", "precisa", "saber", "melhores", "melhor",
        "consejos", "cosas", "secretos", "trucos", "razones", "todo", "necesitas", "mejores", "mejor",
    ]
}
