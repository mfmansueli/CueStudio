//
//  ScriptTextEditing.swift
//  Cue Studio
//

import Foundation

/// Plain text edits the editor offers without AI.
nonisolated enum ScriptTextEditing {
    /// The cue a disclosure opens with. It stays as it is in every language: cues are Cue's markup.
    static let disclosureCue = "[paid partnership]"

    /// The disclosure a sponsored script opens with, said in the script's language (the interface's when it can't be told).
    static func disclosureLine(in language: CueLanguage?) -> String {
        disclosureCue + " " + disclosureSentence(in: language)
    }

    private static func disclosureSentence(in language: CueLanguage?) -> String {
        String(
            localized: "Quick heads-up: this video is sponsored.", writtenIn: language,
            comment: "Written into a sponsored script, in the script's language, after the [paid partnership] cue."
        )
    }

    /// The disclosure sentence in each of Cue's languages: a script translated after it was disclosed still says it.
    private static let disclosureSentences: [String] = Array(Set(CueLanguage.allCases.map { disclosureSentence(in: $0).lowercased() }))

    /// Whether a line is a disclosure: Cue's cue, its sentence in any of Cue's languages, or one of the hashtags creators disclose with.
    static func isDisclosure(_ line: String) -> Bool {
        let lowered = line.lowercased()
        guard !lowered.contains(disclosureCue), !disclosureSentences.contains(where: { lowered.contains($0) }) else { return true }
        return lowered.contains(/#(ad|ads|sponsored|sponsor|publi|publicidade|publicidad|pub|anuncio|werbung|anzeige|reklame|reklam|annons|광고|広告|广告)\b/)
    }

    /// Whether the script discloses the sponsorship anywhere (after a hook written above it, or once translated, it still does).
    static func hasDisclosure(_ text: String) -> Bool {
        CueParser.paragraphs(in: text).contains(where: isDisclosure)
    }

    /// Puts a sponsorship disclosure up front, where platforms and regulators expect it, in the
    /// script's language (`language`, else read from the text).
    static func addingDisclosure(to text: String, language: CueLanguage? = nil) -> String {
        guard !hasDisclosure(text) else { return text }
        let line = disclosureLine(in: language ?? LanguageDetector.language(in: text))
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? line : line + "\n\n" + text
    }

    /// Three hook ideas starting at `rotation`, so "More options" walks through the list. Only the ones said within the hook's few seconds
    /// (`ScriptBlocks.hookTarget`): a hook Cue offers is never one its own tip calls long. Where fewer than three are (a translation runs longer),
    /// the shortest of the rest make up the three.
    static func hookOptions(from hooks: [String], rotation: Int, language: CueLanguage? = nil) -> [String] {
        let fitting = hooks.filter { ReadTime.seconds(for: $0, language: language) <= ScriptBlocks.hookTarget }
        let rest = hooks.filter { !fitting.contains($0) }.sorted { ReadTime.wordCount(in: $0) < ReadTime.wordCount(in: $1) }
        let pool = fitting + rest.prefix(max(0, min(3, hooks.count) - fitting.count))
        guard !pool.isEmpty else { return [] }
        return (0..<min(3, pool.count)).map { pool[($0 + rotation) % pool.count] }
    }
}
