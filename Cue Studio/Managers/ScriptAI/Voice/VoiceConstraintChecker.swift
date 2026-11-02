//
//  VoiceConstraintChecker.swift
//  Cue Studio
//

import Foundation

/// Looks at a script after the model wrote it and says which of the creator's hard rules it broke (plan stage 3, item 7): what they asked to
/// avoid, "I" or "we", the catchphrase that must not open the script, the name of an opening style written out, an emoji when they want
/// none, and a script far shorter than asked. Pure and cheap, so it can run on every script. It only sees what it can be sure of: a word
/// list for what Cue offers to avoid, the creator's own words for what they typed.
nonisolated enum VoiceConstraintChecker {
    /// A script with fewer words than this share of the minimum was not written to length.
    static let shortestShare = 0.7

    /// - Parameters:
    ///   - text: the script, with its stage cues.
    ///   - voice: the creator's voice; nil checks only the length.
    ///   - language: the language the script is in, when it is known (the pronoun check reads English, Portuguese and Spanish).
    ///   - minimumWords: the fewest spoken words that were asked for; 0 skips the length.
    ///   - openingLine: the first sentence the creator picked in Find inspiration (`IdeaBrief`), when the script was asked to open with it: a script
    ///     that does is doing what was asked, even when the line happens to start like a catchphrase or an opening style's name.
    ///   - request: what the creator wrote for this video. What it asks for in so many words is not a broken rule (the owner's B1, 02/11/2026:
    ///     an explicit request beats a "never" of the voice): "neste vídeo, peça para seguir" with Calls to action under Avoid.
    static func violations(
        in text: String, voice: CreatorVoice?, language: CueLanguage? = nil, minimumWords: Int = 0, openingLine: String? = nil,
        request: String? = nil
    ) -> [VoiceViolation] {
        let spoken = CueParser.stripCues(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return [] }
        var found: [VoiceViolation] = []
        if minimumWords > 0 {
            let words = ReadTime.wordCount(in: spoken)
            if Double(words) < Double(minimumWords) * shortestShare {
                found.append(VoiceViolation(
                    kind: .tooShort, detail: "It has only \(words) words and must have at least \(minimumWords): write every block in full."
                ))
            }
        }
        guard let voice else { return found }
        found += avoided(in: spoken, voice: voice, language: language, request: request)
        if let violation = pronoun(in: spoken, expected: voice.resolvedSpeaksAs, language: language) { found.append(violation) }
        if !opensWith(openingLine, spoken) { found += opening(of: spoken, voice: voice) }
        found += VoiceFingerprintRules.drift(in: spoken, voice: voice, language: language)
        return found
    }

    // MARK: - What they asked never to write

    private static func avoided(in spoken: String, voice: CreatorVoice, language: CueLanguage?, request: String?) -> [VoiceViolation] {
        // The model writes “won’t” with a curly apostrophe; the lists are written with a straight one.
        let lowered = spoken.lowercased().replacingOccurrences(of: "’", with: "'")
        let asked = (request ?? "").lowercased().replacingOccurrences(of: "’", with: "'")
        let code = language?.locale.language.languageCode?.identifier ?? "en"
        var found: [VoiceViolation] = []
        for stored in voice.avoid {
            if let rule = VoiceAvoidRule.rule(for: stored) {
                // One violation for each phrase, whichever apostrophe the list spells it with.
                let terms = Set(rule.terms.map { $0.replacingOccurrences(of: "’", with: "'") }).sorted()
                for term in terms where lowered.contains(term) && !asked.contains(term) {
                    found.append(VoiceViolation(kind: .avoided, detail: "It says “\(term.trimmingCharacters(in: .whitespaces))”: \(rule.instruction)."))
                }
                if rule.forbidsEmoji, containsEmoji(spoken) {
                    found.append(VoiceViolation(kind: .emoji, detail: "It has emojis: \(rule.instruction)."))
                }
                // Its last two sentences ask the viewer for something, in the words of the script's language, and the request didn't ask for it.
                if rule.forbidsCallToAction, !WritingOpeningReader.endings(of: spoken, language: code).isEmpty, !asksForAction(asked, language: code) {
                    found.append(VoiceViolation(kind: .avoided, detail: "Its ending asks the viewer to do something: \(rule.instruction)."))
                }
            } else if !asked.contains(stored.lowercased()), let range = spoken.range(of: stored, options: [.caseInsensitive, .diacriticInsensitive]) {
                found.append(VoiceViolation(kind: .avoided, detail: "It says “\(spoken[range])”: never write “\(stored)”."))
            }
        }
        return found
    }

    /// What of their Avoid list this video's request asks for in so many words (the owner's B1, 02/11/2026): the script follows the request, and
    /// the creator is told (`ScriptStarter`). A request that only contradicts a rule by accident ("make a convincing ad" against "Exaggerated
    /// promises") lifts nothing: only the words of the rule, or an ending that asks, do.
    static func lifted(by request: ScriptRequest) -> [String] {
        guard let voice = request.voice else { return [] }
        let asked = request.creatorText.lowercased().replacingOccurrences(of: "’", with: "'")
        let code = request.language?.locale.language.languageCode?.identifier ?? "en"
        return voice.avoid.filter { stored in
            guard let rule = VoiceAvoidRule.rule(for: stored) else { return asked.contains(stored.lowercased()) }
            if rule.forbidsCallToAction { return asksForAction(asked, language: code) }
            return rule.terms.contains { asked.contains($0.replacingOccurrences(of: "’", with: "'")) }
        }
    }

    /// Words of a request that asks, in so many words, for an ending that asks the viewer something: the endings Cue reads in the script's
    /// language (`WritingLexicon`) anywhere in it, or the action named ("call to action", "seguir", "follow").
    private static let namedActions = [
        "call to action", "chamada para ação", "llamada a la acción", "appel à l'action", "cta",
        "follow", "subscribe", "seguir", "seguirem", "sigam", "siga", "segue", "inscreva", "inscrevam", "sígueme", "síganme", "seguirme",
        "suscríbete", "suivre", "suivez", "abonnez", "folgen", "folgt", "abonniert", "seguimi", "seguitemi", "iscriviti",
    ]

    static func asksForAction(_ request: String, language: String) -> Bool {
        let lowered = request.lowercased().replacingOccurrences(of: "’", with: "'")
        guard !lowered.isEmpty else { return false }
        let words = Set(lowered.split { !$0.isLetter }.map(String.init))
        if namedActions.contains(where: { $0.contains(" ") ? lowered.contains($0) : words.contains($0) }) { return true }
        guard let lexicon = WritingLexicon.lexicon(for: language) else { return false }
        // Of the comment words, only the ones that say "comment": "which one" or "what do you think" in a request is a question about the video.
        let comment = lexicon.comment.filter { $0.contains("comment") || $0.contains("coment") || $0.contains("commen") }
        return (lexicon.save + lexicon.follow + comment + lexicon.linkInBio)
            .filter { $0.trimmingCharacters(in: .whitespaces).count >= 4 }
            .contains { lowered.contains($0) }
    }

    /// An emoji is a symbol drawn in color by default (digits and the like are not).
    static func containsEmoji(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.properties.isEmojiPresentation || (0x2600...0x27BF).contains($0.value) && $0.properties.isEmoji }
    }

    // MARK: - "I" or "we"

    private static let singular: [String: Set<String>] = [
        "en": ["i", "i'm", "i’m", "i've", "i’ve", "i'll", "i’ll", "i'd", "i’d", "my", "me", "mine", "myself"],
        "pt": ["eu", "meu", "minha", "meus", "minhas", "mim", "comigo"],
        "es": ["yo", "mi", "mis", "mío", "mía", "conmigo"],
    ]
    private static let plural: [String: Set<String>] = [
        "en": ["we", "we're", "we’re", "we've", "we’ve", "we'll", "we’ll", "we'd", "we’d", "our", "ours", "us", "ourselves"],
        "pt": ["nós", "nosso", "nossa", "nossos", "nossas", "conosco"],
        "es": ["nosotros", "nosotras", "nuestro", "nuestra", "nuestros", "nuestras", "nos"],
    ]

    private static func pronoun(in spoken: String, expected: SpeaksAs, language: CueLanguage?) -> VoiceViolation? {
        let code = language?.locale.language.languageCode?.identifier ?? "en"
        guard let singulars = singular[code], let plurals = plural[code] else { return nil }
        let words = spoken.lowercased().split { !($0.isLetter || $0 == "'" || $0 == "’") }.map(String.init)
        let one = words.filter(singulars.contains).count
        let many = words.filter(plurals.contains).count
        switch expected {
        case .we where one >= 2 && one > many:
            return VoiceViolation(kind: .pronoun, detail: "It speaks as “I” but the creator speaks as a team: say “we” and “our”, never “I”.")
        case .i where many >= 3 && many > one * 2:
            return VoiceViolation(kind: .pronoun, detail: "It speaks as “we” but the creator speaks as one person: say “I” and “my”.")
        default:
            return nil
        }
    }

    // MARK: - The opening

    /// The first words, plain: letters and numbers only, at most the first sentence.
    private static func firstWords(of spoken: String) -> String {
        let head = spoken.prefix(100)
        return VoiceTextValidator.key(String(head)).filter { $0.isLetter || $0.isNumber || $0 == " " }
    }

    /// The script starts with the opening line it was given (its first words, the same once folded).
    static func opensWith(_ line: String?, _ spoken: String) -> Bool {
        guard let line else { return false }
        let start = firstWords(of: line).split(separator: " ").prefix(4).joined(separator: " ")
        guard start.count >= 3 else { return false }
        return firstWords(of: spoken).split(separator: " ").joined(separator: " ").hasPrefix(start)
    }

    private static func opening(of spoken: String, voice: CreatorVoice) -> [VoiceViolation] {
        guard !voice.openings.isEmpty else { return [] }
        var found: [VoiceViolation] = []
        let head = firstWords(of: spoken)
        for phrase in voice.phrases {
            let normalized = VoiceTextValidator.key(phrase).filter { $0.isLetter || $0.isNumber || $0 == " " }
            if normalized.count >= 3, head.hasPrefix(normalized) || head.prefix(normalized.count + 12).contains(normalized) {
                // A catchphrase of a few words said first is a greeting ("Fala, galera!"): measured on an iPhone 15 Pro, a creator whose writing
                // opens with one got it first in 2 of 3 scripts, and writing the script again took it away in 2 of about 13 tries, ~10 s each.
                // Counted, never written again for.
                found.append(VoiceViolation(
                    kind: .catchphraseFirst,
                    detail: "It opens with the catchphrase “\(phrase)”: open the way the creator opens instead, and use the catchphrase later, if at all.",
                    countedOnly: normalized.split(separator: " ").count <= 3
                ))
                break
            }
        }
        let first = VoiceTextValidator.key(String(spoken.prefix(60)))
        for stored in voice.openings {
            let choice = VoiceChoiceCatalog.opening(stored)
            // "POV: …" is what the POV style looks like, not its name leaking.
            for label in [stored] + choice.labels where VoiceTextValidator.key(label) != "pov" {
                let key = VoiceTextValidator.key(label)
                guard first.hasPrefix(key), key.count >= 3 else { continue }
                let after = first.dropFirst(key.count).first
                if after == nil || [".", ":", "-", "—", "\n", "!", ","].contains(after) {
                    found.append(VoiceViolation(
                        kind: .styleName, detail: "It starts with the words “\(label)”, the name of an opening style: show the style, never write its name."
                    ))
                    return found
                }
            }
        }
        return found
    }
}
