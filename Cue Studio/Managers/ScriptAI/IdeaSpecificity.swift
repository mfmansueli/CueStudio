//
//  IdeaSpecificity.swift
//  Cue Studio
//

import Foundation

/// What makes a brief of the model's weak, read from its words alone: an angle that only says the title again (the angle is the claim the video
/// makes, not its subject), and a headline of stock words ("5 tips for…") with nothing particular in it. One weakness is a brief to show later; both
/// make it no idea at all (`isUnusable`), so a perspective that is merely unusual is never thrown away. Whether the opening line leads into the
/// title was tried and left out: on the baseline run it flagged 45 of 108 ideas, most for a synonym ("stretch" for "mobility").
///
/// A title that is its angle's label ("Mito sobre finanças", "Pergunta: …", "Desafio de …") is no idea on its own: the model named what it was
/// asked for instead of writing it. Of 376 titles read in Portuguese and Spanish (03/11/2026), 38 were labels and 33 of those read odd or wrong.
nonisolated enum IdeaSpecificity {
    enum Weakness: String, Hashable, Sendable {
        case angleRestatesTitle, genericTitle, labelTitle
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
        if isLabel(idea.title) { found.append(.labelTitle) }
        return found
    }

    static func isUnusable(_ idea: ThemeIdea) -> Bool {
        let weaknesses = weaknesses(of: idea)
        return weaknesses.count >= 2 || weaknesses.contains(.labelTitle)
    }

    /// The title starts with an angle's name (after "a" or "one"), followed by a colon or by "about", "of", "for" and their kin: "Myth about…",
    /// "Uma lição sobre…", "Reto para…". An angle's name later in the title ("O mito que…") is the title's own words.
    static func isLabel(_ title: String) -> Bool {
        var words = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split { !$0.isLetter && $0 != ":" }
            .flatMap { $0.hasSuffix(":") && $0.count > 1 ? [String($0.dropLast()), ":"] : [String($0)] }
        if let first = words.first, articles.contains(first) { words.removeFirst() }
        guard words.count >= 2, labelWords.contains(words[0]) else { return false }
        return words[1] == ":" || labelLinks.contains(words[1])
    }

    /// The verbs angles start with ("Show…", "Explain…"), folded.
    private static let angleVerbs: Set<String> = [
        "show", "share", "explain", "give", "talk", "tell", "list", "walk", "break", "reveal",
        "mostre", "mostra", "explique", "explica", "compartilhe", "fale", "conte", "de", "liste",
        "muestra", "comparte", "habla", "cuenta", "enumera",
    ]

    /// The angles' names (`IdeaAngle.ask`) as the model puts them at the head of a title, folded, in the languages measured and their neighbours.
    private static let labelWords: Set<String> = [
        "myth", "myths", "question", "lesson", "story", "challenge", "list", "opinion", "prediction", "fact", "comparison", "perspective",
        "mito", "mitos", "pergunta", "licao", "historia", "desafio", "lista", "opiniao", "previsao", "fato", "comparacao", "perspectiva", "reflexao",
        "pregunta", "leccion", "reto", "prediccion", "dato", "comparacion", "comparativa", "duda", "reflexion",
        "mythe", "mythes", "lecon", "histoire", "defi", "liste", "avis", "fait", "comparaison",
        "mythos", "frage", "lektion", "geschichte", "meinung", "prognose", "vorhersage", "fakt", "vergleich",
        "domanda", "lezione", "storia", "sfida", "opinione", "previsione", "fatto", "confronto",
    ]

    /// What follows a label: "about", "of", "for", "that" and their kin, folded.
    private static let labelLinks: Set<String> = [
        "about", "on", "of", "for", "that", "sobre", "de", "do", "da", "dos", "das", "para", "que", "del", "sur", "des", "du", "uber", "zu", "zum",
        "zur", "su", "di", "sul",
    ]

    private static let articles: Set<String> = ["a", "an", "one", "um", "uma", "un", "una", "une", "ein", "eine", "uno"]

    /// Words a headline is made of when it says nothing yet, folded like `IdeaSimilarity.words`, in the languages ideas are measured in most.
    private static let stockWords: Set<String> = [
        "tips", "things", "ways", "secrets", "hacks", "tricks", "ideas", "reasons", "facts", "everything", "need", "know", "best", "top", "ultimate",
        "dicas", "coisas", "formas", "segredos", "truques", "ideias", "motivos", "tudo", "precisa", "saber", "melhores", "melhor",
        "consejos", "cosas", "secretos", "trucos", "razones", "todo", "necesitas", "mejores", "mejor",
    ]
}
