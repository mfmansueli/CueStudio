//
//  AttributedResultDetector.swift
//  Cue Studio
//

import Foundation

/// A result put in the creator's mouth that nobody gave: "Eu perdi 2 quilos em 7 dias" in a script for "O dia em que eu desisti da dieta"
/// (measured on an iPhone 15 Pro, 01/11/2026; `reports/entradas-do-criador-2026-11-01-completo.md` §11, A11b). The owner's B12 (02/11/2026): an
/// imagined scene may have a routine number ("três vezes por semana", "cinco minutos"), never a result, a statistic, a price or a credential.
///
/// It looks only for that: a sentence in the first person (a verb of a result, or the speaker named) with a number of kilos, money, a
/// percentage or followers, when the creator's own text doesn't have that number. A list, a hook, advice and a routine ("três vezes por
/// semana", "perdi três dias de treino") are left alone. Small on purpose, in the five languages it was measured in: it only has to be right when it speaks.
nonisolated enum AttributedResultDetector {
    private struct Words {
        /// A verb of a result in the first person ("perdi", "i lost").
        let verbs: [String]
        /// Words that name the speaker ("eu", "my").
        let speaker: Set<String>
        /// Units a result is counted in (kilos, money, a share).
        let units: [String]
        let numberWords: Set<String>
    }

    private static let words: [String: Words] = [
        "pt": Words(
            verbs: ["perdi", "emagreci", "engordei", "ganhei", "faturei", "lucrei", "economizei", "juntei", "eliminei", "dobrei", "tripliquei",
                    "aumentei", "curei", "me curei", "conquistei",
            ],
            speaker: ["eu", "meu", "minha", "meus", "minhas"],
            units: ["kg", "quilo", "kilo", "libra", "%", "por cento", "reais", "r$", "dólar", "euro", "seguidores", "clientes", "inscritos"],
            numberWords: ["dois", "duas", "três", "quatro", "cinco", "seis", "sete", "oito", "nove", "dez", "vinte", "cem", "mil"]
        ),
        "en": Words(
            verbs: ["i lost", "i dropped", "i gained", "i earned", "i made", "i saved", "i doubled", "i tripled", "i grew", "i increased",
                    "i cured", "i've lost", "i’ve lost", "i've made", "i’ve made",
            ],
            speaker: ["i", "my", "i'm", "i’m", "i've", "i’ve"],
            units: ["pound", "lbs", "kg", "kilo", "%", "percent", "dollar", "$", "€", "followers", "clients", "customers", "subscribers"],
            numberWords: ["two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "twenty", "hundred", "thousand"]
        ),
        "es": Words(
            verbs: ["perdí", "bajé", "adelgacé", "gané", "facturé", "ahorré", "dupliqué", "tripliqué", "aumenté", "me curé", "curé"],
            speaker: ["yo", "mi", "mis"],
            units: ["kilo", "kg", "libra", "%", "por ciento", "euro", "dólar", "peso", "seguidores", "clientes", "suscriptores"],
            numberWords: ["dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "veinte", "cien", "mil"]
        ),
        "fr": Words(
            verbs: ["j'ai perdu", "j’ai perdu", "j'ai pris", "j’ai pris", "j'ai gagné", "j’ai gagné", "j'ai économisé", "j’ai économisé",
                    "j'ai doublé", "j’ai doublé", "j'ai augmenté", "j’ai augmenté", "j'ai guéri", "j’ai guéri",
            ],
            speaker: ["je", "mon", "ma", "mes"],
            units: ["kilo", "kg", "%", "pour cent", "euro", "dollar", "abonnés", "clients"],
            numberWords: ["deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix", "vingt", "cent", "mille"]
        ),
        "it": Words(
            verbs: ["ho perso", "ho preso", "ho guadagnato", "ho risparmiato", "ho raddoppiato", "ho triplicato", "ho aumentato", "ho fatturato",
                    "sono guarito", "sono guarita", "sono dimagrito", "sono dimagrita",
            ],
            speaker: ["io", "mio", "mia", "miei", "mie"],
            units: ["chili", "chilo", "kg", "%", "per cento", "euro", "dollari", "follower", "clienti", "iscritti"],
            numberWords: ["due", "tre", "quattro", "cinque", "sei", "sette", "otto", "nove", "dieci", "venti", "cento", "mille"]
        ),
    ]

    /// The sentences of `text` that state a result of the speaker's that `request` doesn't give, in the script's language (`code`, "pt-BR"
    /// or "pt"); none for a language it doesn't know.
    static func findings(in text: String, language code: String?, request: String) -> [String] {
        guard let code, let words = words[String(code.prefix(2)).lowercased()] else { return [] }
        let given = numbers(in: request.lowercased(), words: words)
        return sentences(of: CueParser.stripCues(text)).filter { sentence in
            let lowered = sentence.lowercased()
            let said = numbers(in: lowered, words: words)
            // A number the creator gave ("Como perdi 10 quilos") is theirs to say.
            guard !said.isEmpty, !said.isSubset(of: given), words.units.contains(where: lowered.contains) else { return false }
            // In the first person: a verb of a result ("perdi"), or the speaker named ("eu", "my").
            if words.verbs.contains(where: lowered.contains) { return true }
            let tokens = Set(lowered.split { !($0.isLetter || $0 == "'" || $0 == "’") }.map(String.init))
            return !tokens.isDisjoint(with: words.speaker)
        }
    }

    private static func numbers(in text: String, words: Words) -> Set<String> {
        let digits = text.matches(of: /\d+(?:[.,]\d+)?/).map { String($0.output) }
        let named = text.split { !$0.isLetter }.map(String.init).filter(words.numberWords.contains)
        return Set(digits + named)
    }

    private static func sentences(of text: String) -> [String] {
        text.matches(of: /[^.!?…\n]+[.!?…]*/).map { String($0.output).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
