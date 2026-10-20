//
//  InspirationCardContent.swift
//  Cue Studio
//

import Foundation

/// What the featured card of Find inspiration says about one idea: a small category line ("PERSONAL FINANCE · EXPLAINER"), the video's
/// title (the strongest line), and, for an idea with a brief, "Your point of view" and "Opening line". An idea without a brief (a starter written
/// before briefs, a note from the Logbook) is its title alone: nothing is made up to fill the card.
nonisolated struct InspirationCardContent: Hashable, Sendable {
    /// The topic, the subtopic when the brief has one, and the kind of video, joined by " · " (shown in capitals).
    let category: String
    let title: String
    /// The perspective, when the idea has a brief that says one.
    let angle: String?
    /// The suggested first sentence, without quotes (the card draws them), when the brief has one.
    let openingLine: String?
    /// The idea is one of the creator's own notes from the Logbook.
    let isLogbookNote: Bool

    init(idea: ThemeIdea, topics: [IdeaTopic], logbookLabel: String) {
        isLogbookNote = idea.logbookID != nil
        title = Self.trimmed(idea.title) ?? Self.trimmed(idea.brief?.subject) ?? ""
        angle = Self.trimmed(idea.brief?.angle)
        openingLine = Self.trimmed(idea.brief?.openingLine).map(Self.unquoted)
        if isLogbookNote {
            category = logbookLabel
        } else {
            let parts = [
                InspirationFilterOption.topicLabel(of: idea, among: topics), Self.trimmed(idea.brief?.subtopic), Self.trimmed(idea.kind),
            ]
            // The subtopic is left out when it only repeats the topic.
            var kept: [String] = []
            for part in parts.compactMap({ $0 }) where !kept.contains(where: { $0.localizedCaseInsensitiveCompare(part) == .orderedSame }) {
                kept.append(part)
            }
            category = kept.joined(separator: " · ")
        }
    }

    /// The card has more than its title to show (an angle, an opening line, or both).
    var hasBrief: Bool { angle != nil || openingLine != nil }

    private static func trimmed(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    /// The model may already quote its line; the card draws its own quotes.
    private static func unquoted(_ line: String) -> String {
        let quotes = CharacterSet(charactersIn: "\"“”«»„‘’'「」")
        let inner = line.trimmingCharacters(in: quotes.union(.whitespaces))
        return inner.isEmpty ? line : inner
    }
}
