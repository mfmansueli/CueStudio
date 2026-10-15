//
//  DraftAssessment.swift
//  Cue Studio
//

import Foundation

/// What a written draft is worth when two drafts of one script compete (`RevisionChoice`): how serious what it breaks is, whether it still says
/// the opening line the creator picked, how much of the idea or angle it covers, how much it says and whether it ends, and how much it repeats
/// itself. Pure: measured from the text and the request alone.
nonisolated struct DraftAssessment: Hashable, Sendable {
    /// The sum of the severities of what it breaks (`VoiceViolation.Kind.severity`).
    let severity: Int
    let spokenWords: Int
    /// The last sentence stops without its end (the model was cut off).
    let isCut: Bool
    /// It opens with the line the creator picked in Find inspiration; nil when there was none.
    let opensWithBrief: Bool?
    /// The share of the angle's words (or the idea's, without a brief) it uses; nil when there is nothing to cover.
    let coverage: Double?
    /// `ScriptRepetition.repeatedShare`.
    let repetition: Double

    init(text: String, violations: [VoiceViolation], request: ScriptRequest) {
        let language = request.language?.locale.language.languageCode?.identifier
        let spoken = CueParser.stripCues(text).trimmingCharacters(in: .whitespacesAndNewlines)
        severity = violations.reduce(0) { $0 + $1.kind.severity }
        spokenWords = ReadTime.wordCount(in: spoken)
        isCut = spoken.last.map { !Self.endings.contains($0) } ?? true
        if let line = request.brief?.openingLine, !line.isEmpty {
            opensWithBrief = VoiceConstraintChecker.opensWith(line, spoken)
        } else {
            opensWithBrief = nil
        }
        coverage = Self.coverage(of: Self.target(of: request), in: spoken, language: language)
        repetition = ScriptRepetition.repeatedShare(in: spoken, language: language)
    }

    /// What the script must cover: the angle of the brief, else the idea the creator typed.
    private static func target(of request: ScriptRequest) -> String? {
        if let angle = request.brief?.angle, !angle.isEmpty { return angle }
        if case .prompt(let idea) = request.source { return idea }
        return nil
    }

    /// The share of `target`'s meaningful words found in `text` (the same word, or the same first five letters: "habit" and "habits").
    static func coverage(of target: String?, in text: String, language: String?) -> Double? {
        guard let target else { return nil }
        let wanted = Set(IdeaFocus.words(in: target, language: language))
        guard !wanted.isEmpty else { return nil }
        let present = Set(IdeaFocus.words(in: text, language: language))
        let prefixes = Set(present.filter { $0.count >= 5 }.map { String($0.prefix(5)) })
        let found = wanted.filter { present.contains($0) || ($0.count >= 5 && prefixes.contains(String($0.prefix(5)))) }
        return Double(found.count) / Double(wanted.count)
    }

    /// What a finished sentence ends with, in the scripts the app writes.
    private static let endings: Set<Character> = [".", "!", "?", "…", "\"", "”", "»", ")", "。", "！", "？", "؟", "।"]
}
