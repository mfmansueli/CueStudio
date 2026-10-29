//
//  ScriptVerbatimRequirements.swift
//  Cue Studio
//

import Foundation

/// Recognizes explicit "include exactly: …" forms, not arbitrary semantic requirements. Quoted
/// text may be followed by other instructions. Unquoted text must be a single final sentence;
/// ambiguous multi-sentence tails stay in the original request rather than becoming a guessed rule.
nonisolated enum ScriptVerbatimRequirements {
    private static let directives = [
        #"(?:include|say|write|repeat)\s+(?:exactly|verbatim)"#,
        #"(?:inclua|inclui|diga|escreva|repita)\s+(?:exatamente|literalmente)"#,
        #"(?:incluye|incluya|di|diga|escribe|escriba|repite|repita)\s+(?:exactamente|literalmente)"#,
        #"(?:inclus|incluez|inclure|ajoute|ajoutez|écris|écrivez|dis|dites)\s+(?:exactement|mot pour mot)"#,
        #"(?:schreibe|schreiben|sage|sagen)\s+(?:genau|wörtlich)"#,
        #"(?:includi|scrivi|ripeti)\s+(?:esattamente|letteralmente)"#,
        #"(?:そのまま書いて|そのまま入れて|正確に書いて|次をそのまま)"#,
        #"(?:다음을 그대로|그대로 써 주세요|정확히 써 주세요)"#,
        #"(?:原样写|原樣寫|逐字写|逐字寫|原样包含|原樣包含)"#,
        #"(?:हूबहू लिखें|ठीक ऐसा लिखें|शब्दशः लिखें)"#,
        #"(?:tulis|sertakan|ulangi)\s+(?:persis|secara persis)"#,
        #"(?:اكتب حرفيا|اكتب حرفيًا|أدرج بالضبط|كرر حرفيا)"#,
        #"(?:aynen yaz|tam olarak yaz|aynen ekle)"#,
        #"(?:เขียนตามนี้|เขียนให้ตรงตามนี้|ใส่ข้อความนี้)"#,
        #"(?:viết nguyên văn|thêm nguyên văn|ghi nguyên văn)"#,
        #"(?:schrijf|zeg|herhaal)\s+(?:precies|letterlijk)"#,
        #"(?:skriv|säg|upprepa)\s+(?:exakt|ordagrant)"#,
        #"(?:skriv|sig|gentag)\s+(?:præcis|ordret)"#,
        #"(?:skriv|si|gjenta)\s+(?:nøyaktig|ordrett)"#,
    ]
    private static let expression = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z])(?:"# + directives.joined(separator: "|") + #")\s*[:：]\s*"#,
        options: .caseInsensitive
    )

    static func phrases(in source: ScriptRequest.Source) -> [String] {
        guard case .prompt(let text) = source, let expression else { return [] }
        var phrases: [String] = []
        for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            let prefix = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            // A negated directive is not a requirement to include its text.
            if prefix.range(
                of: #"(?:\b(?:not|never|don't|não|nao|nunca|no|nicht|non|niet|inte|ikke|jangan|đừng|không)|لا|不要|别|別|อย่า|मत)\s*$"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil { continue }
            guard let phrase = phrase(in: String(text[range.upperBound...])), !phrases.contains(phrase) else { continue }
            phrases.append(phrase)
        }
        return phrases
    }

    /// Exact case/punctuation with canonical Unicode equivalence. Latin/numeric targets must not
    /// be fragments of a different name or number; CJK particles may directly follow a Latin name.
    static func contains(_ phrase: String, in text: String) -> Bool {
        let phrase = phrase.precomposedStringWithCanonicalMapping
        guard !phrase.isEmpty else { return false }
        let token = #"[\p{Latin}\p{N}\p{M}_]"#
        let startsToken = phrase.first.map { String($0).range(of: token, options: .regularExpression) != nil } ?? false
        let endsToken = phrase.last.map { String($0).range(of: token, options: .regularExpression) != nil } ?? false
        let pattern = (startsToken ? "(?<!\(token))" : "") + NSRegularExpression.escapedPattern(for: phrase) + (endsToken ? "(?!\(token))" : "")
        return text.precomposedStringWithCanonicalMapping.range(of: pattern, options: .regularExpression) != nil
    }

    private static func phrase(in tail: String) -> String? {
        let text = tail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = text.first else { return nil }
        let quotes: [Character: Character] = ["\"": "\"", "“": "”", "«": "»", "「": "」", "『": "』"]
        if let end = quotes[first] {
            let rest = text.dropFirst()
            guard let closing = rest.firstIndex(of: end) else { return nil }
            let phrase = String(rest[..<closing])
            return phrase.isEmpty ? nil : phrase
        }
        guard !text.contains(where: \.isNewline) else { return nil }
        let boundaries = text.ranges(of: /[.!?。！？](?:\s|$)/)
        guard boundaries.count <= 1, boundaries.first.map({ $0.upperBound == text.endIndex }) ?? true else { return nil }
        return text
    }
}
