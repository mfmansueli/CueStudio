//
//  GenderAgreementChecker.swift
//  Cue Studio
//

import Foundation

/// A word about the creator in the gender they didn't choose ("Eu estou cansado" for a creator who picked Feminine), in Portuguese, Spanish,
/// French and Italian (the owner's B8, 02/11/2026; §11.7). A triage, as the owner set it: a short list of the words a first person most often
/// agrees (tired, alone, ready, arrived…) right after the verbs that carry them ("estou", "me quedé", "je suis", "sono"). It speaks only when it
/// is sure; the word that counts is a native reader's.
nonisolated enum GenderAgreementChecker {
    private struct Words: Sendable {
        /// What comes before a word that agrees with "I": "estou", "fiquei", "me sinto".
        let singular: [String]
        /// The same for "we".
        let pluralLeads: [String]
        /// Masculine and feminine singular, in pairs.
        let pairs: [(String, String)]
        /// Words that may sit between ("muito", "très").
        let between: Set<String>
        /// The plural of a singular form.
        let pluralOf: @Sendable (String) -> String
    }

    private static func romancePlural(_ word: String) -> String { word.hasSuffix("s") ? word : word + "s" }

    private static func italianPlural(_ word: String) -> String {
        switch true {
        case word.hasSuffix("co"): String(word.dropLast(2)) + "chi"
        case word.hasSuffix("ca"): String(word.dropLast(2)) + "che"
        case word.hasSuffix("o"): String(word.dropLast()) + "i"
        case word.hasSuffix("a"): String(word.dropLast()) + "e"
        default: word
        }
    }

    private static func frenchPlural(_ word: String) -> String {
        word.hasSuffix("s") || word.hasSuffix("x") ? word : word + "s"
    }

    private static let words: [String: Words] = [
        "pt": Words(
            singular: ["estou", "tô", "estava", "fiquei", "ficava", "sou", "era", "fui", "me sinto", "me senti", "me sentia", "ando", "continuo",
                       "acordei", "cheguei",
            ],
            pluralLeads: ["estamos", "ficamos", "somos", "éramos", "fomos", "nos sentimos", "chegamos"],
            pairs: [("cansado", "cansada"), ("sozinho", "sozinha"), ("obrigado", "obrigada"), ("preocupado", "preocupada"),
                    ("animado", "animada"), ("ansioso", "ansiosa"), ("nervoso", "nervosa"), ("acostumado", "acostumada"),
                    ("apaixonado", "apaixonada"), ("frustrado", "frustrada"), ("exausto", "exausta"), ("orgulhoso", "orgulhosa"),
                    ("perdido", "perdida"), ("focado", "focada"), ("motivado", "motivada"), ("empolgado", "empolgada"),
                    ("chateado", "chateada"), ("pronto", "pronta"), ("atrasado", "atrasada"), ("decidido", "decidida"),
                    ("desanimado", "desanimada"), ("grato", "grata"), ("viciado", "viciada"), ("convencido", "convencida"),
            ],
            between: ["muito", "tão", "super", "bem", "meio", "mais", "um", "pouco", "totalmente", "completamente"],
            pluralOf: romancePlural
        ),
        "es": Words(
            singular: ["estoy", "estaba", "estuve", "me quedé", "me quedaba", "soy", "era", "fui", "me siento", "me sentí", "me sentía", "sigo",
                       "ando", "llegué", "terminé",
            ],
            pluralLeads: ["estamos", "nos quedamos", "somos", "éramos", "fuimos", "nos sentimos", "llegamos"],
            pairs: [("cansado", "cansada"), ("solo", "sola"), ("agotado", "agotada"), ("preocupado", "preocupada"), ("emocionado", "emocionada"),
                    ("nervioso", "nerviosa"), ("ansioso", "ansiosa"), ("acostumbrado", "acostumbrada"), ("enamorado", "enamorada"),
                    ("frustrado", "frustrada"), ("orgulloso", "orgullosa"), ("perdido", "perdida"), ("motivado", "motivada"),
                    ("asustado", "asustada"), ("agradecido", "agradecida"), ("listo", "lista"), ("convencido", "convencida"),
                    ("contento", "contenta"), ("harto", "harta"), ("aburrido", "aburrida"), ("obsesionado", "obsesionada"),
                    ("encantado", "encantada"), ("seguro", "segura"),
            ],
            between: ["muy", "tan", "súper", "bastante", "algo", "un", "poco", "totalmente", "completamente"],
            pluralOf: romancePlural
        ),
        "fr": Words(
            singular: ["je suis", "j'étais", "j’étais", "je me sens", "je me sentais", "je reste", "je me suis senti", "je me suis sentie"],
            pluralLeads: ["nous sommes", "nous étions", "on est", "on était"],
            pairs: [("allé", "allée"), ("arrivé", "arrivée"), ("resté", "restée"), ("tombé", "tombée"), ("venu", "venue"), ("parti", "partie"),
                    ("sorti", "sortie"), ("rentré", "rentrée"), ("devenu", "devenue"), ("fatigué", "fatiguée"), ("épuisé", "épuisée"),
                    ("seul", "seule"), ("prêt", "prête"), ("content", "contente"), ("motivé", "motivée"), ("inquiet", "inquiète"),
                    ("nerveux", "nerveuse"), ("heureux", "heureuse"), ("perdu", "perdue"), ("convaincu", "convaincue"), ("fier", "fière"),
                    ("habitué", "habituée"), ("amoureux", "amoureuse"), ("déçu", "déçue"),
            ],
            between: ["très", "trop", "si", "tellement", "un", "peu", "assez", "complètement", "vraiment"],
            pluralOf: frenchPlural
        ),
        "it": Words(
            singular: ["sono", "ero", "mi sento", "mi sentivo", "mi sono sentito", "mi sono sentita", "rimango", "resto"],
            pluralLeads: ["siamo", "eravamo", "ci sentiamo"],
            pairs: [("stanco", "stanca"), ("stato", "stata"), ("arrivato", "arrivata"), ("andato", "andata"), ("rimasto", "rimasta"),
                    ("uscito", "uscita"), ("partito", "partita"), ("tornato", "tornata"), ("caduto", "caduta"), ("venuto", "venuta"),
                    ("diventato", "diventata"), ("solo", "sola"), ("preoccupato", "preoccupata"), ("emozionato", "emozionata"),
                    ("nervoso", "nervosa"), ("ansioso", "ansiosa"), ("abituato", "abituata"), ("innamorato", "innamorata"),
                    ("orgoglioso", "orgogliosa"), ("motivato", "motivata"), ("grato", "grata"), ("pronto", "pronta"),
                    ("sicuro", "sicura"), ("contento", "contenta"), ("stufo", "stufa"), ("convinto", "convinta"),
            ],
            between: ["molto", "così", "troppo", "super", "un", "po'", "po’", "davvero", "proprio", "già"],
            pluralOf: italianPlural
        ),
    ]

    /// The words in `text` that agree in the gender the creator didn't choose: none when they chose none (nil), for a language it doesn't
    /// read, and for "we" unless the group's agreement was chosen.
    static func findings(in text: String, agreement: VoiceAgreement, speaksAs: SpeaksAs, language code: String?) -> [String] {
        guard let code, let words = words[String(code.prefix(2)).lowercased()] else { return [] }
        let chosen = speaksAs == .we ? agreement.group : agreement.speaker
        guard let chosen else { return [] }
        let leads = speaksAs == .we ? words.pluralLeads : words.singular
        let wrong: [String] = words.pairs.flatMap { masculine, feminine -> [String] in
            let forms: [String] = switch chosen {
            case .feminine: [masculine]
            case .masculine: [feminine]
            case .neutral: [masculine, feminine]
            }
            return speaksAs == .we ? forms.map(words.pluralOf) : forms
        }
        let tokens = CueParser.stripCues(text).lowercased()
            .split { !($0.isLetter || $0 == "'" || $0 == "’") }.map(String.init)
        var found: [String] = []
        for (index, token) in tokens.enumerated() where wrong.contains(token) {
            // Back over the words that may sit between, then the lead must end right there.
            var start = index - 1
            while start >= 0, words.between.contains(tokens[start]) { start -= 1 }
            guard start >= 0 else { continue }
            let before = tokens[max(0, start - 3)...start].joined(separator: " ")
            if leads.contains(where: { before == $0 || before.hasSuffix(" " + $0) }) { found.append(token) }
        }
        return found
    }
}
