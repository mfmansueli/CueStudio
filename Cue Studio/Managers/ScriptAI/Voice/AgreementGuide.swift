//
//  AgreementGuide.swift
//  Cue Studio
//

import Foundation

/// What the AI is told of the creator's grammar in the script's language (`VoiceAgreement`, the owner's B8, 02/11/2026; §11.7). Only the
/// languages that mark it get a line: the agreement in Portuguese, Spanish, French, Italian, Hindi and Arabic; the form of address where a
/// language has two. Not chosen is never the masculine (measured on an iPhone 15 Pro, 01/11/2026: women writing in Portuguese, Spanish, Italian
/// and French got masculine forms with nothing in the profile that said otherwise).
nonisolated enum AgreementGuide {
    private struct Agreement {
        let feminine: String
        let masculine: String
        let groupFeminine: String
        let groupMasculine: String
    }

    private static let agreements: [String: Agreement] = [
        "pt": Agreement(feminine: "cansada, sozinha, obrigada", masculine: "cansado, sozinho, obrigado",
                        groupFeminine: "cansadas, prontas", groupMasculine: "cansados, prontos"),
        "es": Agreement(feminine: "cansada, sola, agotada", masculine: "cansado, solo, agotado",
                        groupFeminine: "nosotras, cansadas", groupMasculine: "nosotros, cansados"),
        "fr": Agreement(feminine: "je suis allée, fatiguée, prête", masculine: "je suis allé, fatigué, prêt",
                        groupFeminine: "nous sommes allées, prêtes", groupMasculine: "nous sommes allés, prêts"),
        "it": Agreement(feminine: "sono arrivata, stanca, pronta", masculine: "sono arrivato, stanco, pronto",
                        groupFeminine: "siamo arrivate, stanche", groupMasculine: "siamo arrivati, stanchi"),
        "hi": Agreement(feminine: "मैं थक गई, मैं जाती हूँ", masculine: "मैं थक गया, मैं जाता हूँ",
                        groupFeminine: "हम थक गईं", groupMasculine: "हम थक गए"),
        "ar": Agreement(feminine: "أنا متعبة", masculine: "أنا متعب", groupFeminine: "نحن متعبات", groupMasculine: "نحن متعبون"),
    ]

    /// The informal and the formal "you", where the default informal is safe to say for social video; Hindi, Korean and Japanese get a line only
    /// when the creator picks one (their polite form is the usual one with an audience).
    private static let addresses: [String: (informal: String, formal: String, byDefault: Bool)] = [
        "pt-BR": ("você", "o senhor / a senhora", true), "pt-PT": ("tu", "você / o senhor / a senhora", true),
        "es": ("tú", "usted", true), "fr": ("tu", "vous", true), "de": ("du", "Sie", true), "it": ("tu", "Lei", true),
        "nl": ("je", "u", true), "tr": ("sen", "siz", true), "id": ("kamu", "Anda", true),
        "hi": ("तुम", "आप", false), "ko": ("반말", "존댓말", false), "ja": ("casual speech", "polite speech (です・ます)", false),
    ]

    /// - Parameters:
    ///   - agreement: the creator's (nil when "Write in my voice" is off: nothing about them is known).
    ///   - speaksAs: who is talking, which says whether the speaker's or the group's agreement applies.
    ///   - language: the script's language, a code like "pt-BR" or "es" (its variant, when there is one, decides "tu" or "você").
    ///   - chosenOnly: only what the creator chose, as a tool says it: an edit doesn't change the agreement or the address of a script nobody
    ///     asked it to.
    static func lines(for agreement: VoiceAgreement?, speaksAs: SpeaksAs, language code: String?, chosenOnly: Bool = false) -> [String] {
        guard let code else { return [] }
        let base = String(code.prefix(2)).lowercased()
        let name = Locale(identifier: "en").localizedString(forLanguageCode: base) ?? base
        var lines: [String] = []
        if let words = agreements[base] {
            let line = speaksAs == .we
                ? groupLine(agreement?.group, words: words, name: name)
                : speakerLine(agreement?.speaker, words: words, name: name, chosenOnly: chosenOnly)
            if let line { lines.append(line) }
        }
        let region = code.replacingOccurrences(of: "_", with: "-")
        if let address = addresses[region] ?? addresses[base],
           let line = addressLine(agreement?.address, address: address, chosenOnly: chosenOnly) {
            lines.append(line)
        }
        return lines
    }

    private static func speakerLine(_ gender: WordGender?, words: Agreement, name: String, chosenOnly: Bool) -> String? {
        switch gender {
        case .feminine?: "In \(name), every word about the creator agrees in the feminine (\(words.feminine)); never the masculine."
        case .masculine?: "In \(name), every word about the creator agrees in the masculine (\(words.masculine)); never the feminine."
        case .neutral?:
            "In \(name), the creator asked for no gender: rephrase so no word about them marks one (“I ran out of energy”, not “tired”), "
                + "never with invented forms."
        case nil where chosenOnly: nil
        case nil: "In \(name), the creator's gender isn't known: prefer wording about them that marks none, and never assume the masculine."
        }
    }

    private static func groupLine(_ gender: WordGender?, words: Agreement, name: String) -> String? {
        switch gender {
        case .feminine?: "In \(name), “we” is a group written in the feminine (\(words.groupFeminine))."
        case .masculine?: "In \(name), “we” is a group written in the masculine (\(words.groupMasculine))."
        case .neutral?: "In \(name), the group asked for no gender: rephrase so no word about “we” marks one."
        case nil: nil
        }
    }

    private static func addressLine(_ form: AddressForm?, address: (informal: String, formal: String, byDefault: Bool), chosenOnly: Bool) -> String? {
        switch form {
        case .formal?: "Address the viewer formally (\(address.formal)) throughout."
        case .informal?: "Address the viewer informally (\(address.informal)), as a friend."
        case nil where address.byDefault && !chosenOnly: "Address the viewer informally (\(address.informal)), as a friend."
        case nil: nil
        }
    }

    /// "pt-PT" for a request: the variant when there is one, else its language.
    static func code(of request: ScriptRequest) -> String? {
        request.languageVariant.map { $0.identifier.replacingOccurrences(of: "_", with: "-") } ?? request.language?.rawValue
    }

    /// "pt-PT" for a language the model is held to.
    static func code(of language: Locale.Language?) -> String? {
        guard let language, let base = language.languageCode?.identifier else { return nil }
        return language.region.map { "\(base)-\($0.identifier)" } ?? base
    }
}
