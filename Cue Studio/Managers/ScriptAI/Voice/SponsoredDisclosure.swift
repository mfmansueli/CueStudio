//
//  SponsoredDisclosure.swift
//  Cue Studio
//

import Foundation

/// Whether a sponsored ad's script says that it is paid ("Paid partnership · #ad" is always on, `BrandBrief`), in any of Cue's languages.
/// Measured on two iPhones (the Ultra study on Apple Intelligence, 04/11/2026): Private Cloud Compute left it out of 6 ads in 8 although the
/// request asks for it, so a script without it is written once more (`VoiceCheckedWriting`). A triage of the words creators use for it, folded
/// (no case, no accents): it speaks only when none of them is there. Broader than the editor's `ScriptTextEditing.isDisclosure`, which tells a
/// disclosure line apart from the hook by Cue's own sentence, its cue and the hashtags alone, so a hook that talks about advertising stays one.
nonisolated enum SponsoredDisclosure {
    /// Said anywhere in the script, in each language.
    private static let phrases: [String] = [
        // English, Portuguese, Spanish
        "paid partnership", "sponsor", "advertisement", "parceria paga", "publicidade", "patrocin", "anuncio pago", "publicidad",
        "colaboracion pagada", "colaboracion remunerada",
        // French, German, Italian, Dutch
        "partenariat remunere", "collaboration commerciale", "publicite", "anzeige", "werbung", "bezahlte partnerschaft", "bezahlte kooperation",
        "pubblicita", "collaborazione retribuita", "partnership retribuita", "betaalde samenwerking", "advertentie", "reclame",
        // Swedish, Danish, Norwegian, Turkish, Indonesian, Vietnamese
        "betalt samarbete", "reklam", "annons", "betalt samarbejde", "annonce", "betalt samarbeid", "sponsorlu", "ucretli is birligi",
        "ucretli isbirligi", "iklan", "kerja sama berbayar", "quang cao", "tai tro", "hop tac co tra phi",
        // Japanese, Korean, Chinese, Hindi, Arabic, Thai
        "広告", "プロモーション", "タイアップ", "광고", "협찬", "广告", "廣告", "赞助", "贊助", "业配", "業配", "合作推广", "合作推廣",
        "विज्ञापन", "प्रायोजित", "पेड पार्टनरशिप", "إعلان", "اعلان", "برعاية", "شراكة مدفوعة", "โฆษณา", "สปอนเซอร์", "ได้รับการสนับสนุน",
    ].map(folded)

    /// Said as a word of its own: hashtags, and short words that are inside others too ("publi" in "público", "#ad" in "#adoro").
    private static let words: Set<String> = [
        "#ad", "#ads", "#publi", "#publicidade", "#publicidad", "#pub", "#anzeige", "#werbung", "#adv", "#sponsored", "#reklam", "#pr", "publi",
        "adv",
    ]

    static func isSaid(in text: String) -> Bool {
        let spoken = folded(CueParser.stripCues(text))
        if phrases.contains(where: { spoken.contains($0) }) { return true }
        let tokens = spoken.split { !($0.isLetter || $0.isNumber || $0 == "#") }.map(String.init)
        return tokens.indices.contains { index in
            if words.contains(tokens[index]) { return true }
            // "ad" alone is English only when the ad is named ("this is an ad", "a paid ad").
            guard tokens[index] == "ad" || tokens[index] == "ads", index > 0 else { return false }
            return ["an", "paid", "this", "sponsored"].contains(tokens[index - 1])
        }
    }

    private static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
