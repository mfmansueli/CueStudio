//
//  IdeaBriefReader.swift
//  Cue Studio
//

import Foundation

/// The model's ideas as the card and Find inspiration show them. Pure text, so it is tested without the model: each answer is cleaned (markdown,
/// wrapping quotes, a label like "Angle:" the model wrote out), matched to the slot it was asked for (the slot says the angle, the topic and so the
/// kind of video; the model's own word for either is not trusted), and kept to the size of a card (`cardLimit`). An answer without a title or
/// an opening line is no idea and is dropped.
nonisolated enum IdeaBriefReader {
    /// One idea as the model wrote it.
    struct Answer: Sendable {
        var title: String
        var angle: String
        var openingLine: String
    }

    /// The ideas of a batch, in the slots' order; `language` is the one they were asked in (a minimal identifier), `phrases` the creator's
    /// catchphrases.
    static func ideas(from answers: [Answer], slots: [IdeaSlot], language: String?, phrases: [String] = []) -> [ThemeIdea] {
        zip(answers, slots).compactMap { answer, slot in idea(from: answer, slot: slot, language: language, phrases: phrases) }
    }

    static func idea(from answer: Answer, slot: IdeaSlot, language: String?, phrases: [String] = []) -> ThemeIdea? {
        let title = clean(answer.title, labels: ["title"], language: language)
        let angle = clean(answer.angle, labels: ["angle", "your angle"], language: language)
        let opening = withoutCatchphrase(
            clean(answer.openingLine, labels: ["opening line", "opening", "hook", "open with"], language: language), phrases: phrases
        )
        guard !title.isEmpty, !opening.isEmpty else { return nil }
        var idea = ThemeIdea(
            title: title, kind: slot.angle.kind, length: length(for: slot.angle), niche: slot.topic.niche ?? .lifestyle,
            topic: slot.topic.niche == nil ? slot.topic.label : nil
        )
        idea.angle = slot.angle.rawValue
        idea.tie = slot.tie
        idea.brief = IdeaBrief(
            subject: title, angle: angle, openingLine: opening,
            subtopic: slot.subtopic ?? subtopic(of: slot.topic, in: [title, angle, opening], language: language),
            language: language, angleKind: slot.angle.rawValue, topicKey: IdeaTaste.topicKey(of: slot.topic), topic: slot.topic.name
        ).fitted(to: Self.cardLimit)
        // The headline the card shows is the brief's, cut the same way.
        idea.title = idea.brief?.subject ?? title
        return idea
    }

    /// The batch after Private Cloud Compute's edit (`IdeaEdits`): each idea in the words it wrote, the ones it dropped (nil) gone with their slots.
    /// An idea it gave no edit for, or an edit without a title or an opening line, stays as the iPhone wrote it; an edit that drops every idea is
    /// not trusted, and the batch stays as it was.
    static func edited(_ answers: [Answer], slots: [IdeaSlot], by edits: [Answer?]) -> (answers: [Answer], slots: [IdeaSlot]) {
        guard edits.contains(where: { $0 != nil }) else { return (answers, slots) }
        var kept: (answers: [Answer], slots: [IdeaSlot]) = ([], [])
        for (index, pair) in zip(answers, slots).enumerated() {
            guard index < edits.count else {
                kept.answers.append(pair.0)
                kept.slots.append(pair.1)
                continue
            }
            guard let edit = edits[index] else { continue }
            let usable = !edit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !edit.openingLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            kept.answers.append(usable ? edit : pair.0)
            kept.slots.append(pair.1)
        }
        return kept
    }

    /// A bad-language item never reaches the shared pool, even if the rest of its batch is valid.
    static func validated(_ ideas: [ThemeIdea], language: Locale.Language?) throws -> [ThemeIdea] {
        guard let language else { return ideas }
        let valid = ideas.filter { idea in
            let text = [idea.title, idea.brief?.angle ?? "", idea.brief?.openingLine ?? ""].joined(separator: " ")
            // The whole brief can pass on its angle and opening line with the title in English: the title is the card's largest words.
            return OutputLanguageCheck.isPlausible(text, in: language) && OutputLanguageCheck.isTitlePlausible(idea.title, in: language)
        }
        guard !valid.isEmpty else { throw ScriptAIError.wrongLanguage }
        return valid
    }

    /// The most a brief of the model's may hold, laid out: a model that runs on is cut here (at a word) so the card stays a card; the field gets
    /// its own 200 (`IdeaBrief.composerText`).
    static let cardLimit = 300

    /// A story or a day in the life takes longer to tell than a tip.
    static func length(for angle: IdeaAngle) -> ScriptLength {
        switch angle {
        case .story, .dayInLife, .comparison: .minutes2
        default: .minute1
        }
    }

    /// The subtopic the idea is about, when it names one of the topic's.
    private static func subtopic(of topic: IdeaTopic, in parts: [String], language: String?) -> String? {
        let words = Set(parts.flatMap { IdeaFocus.words(in: $0, language: language) })
        // The same word, or the same start of a longer one ("Italian" in "Italians"), as `IdeaFocus` matches topics.
        func same(_ lhs: String, _ rhs: String) -> Bool {
            lhs == rhs || (lhs.count >= 5 && rhs.count >= 5 && lhs.prefix(5) == rhs.prefix(5))
        }
        return topic.subtopics.first { subtopic in
            let needed = IdeaFocus.words(in: subtopic, language: nil)
            return !needed.isEmpty && needed.allSatisfy { word in words.contains { same($0, word) } }
        }
    }

    /// An idea of the model's as an older version kept it, without the dashes it may hold (`IdeaSuggestionService` restores them).
    static func withoutDashes(_ idea: ThemeIdea) -> ThemeIdea {
        var idea = idea
        let language = (idea.brief?.language).map(Locale.Language.init(identifier:))
        idea.title = DashRewriter.rewrite(idea.title, language: language)
        if var brief = idea.brief {
            brief.subject = DashRewriter.rewrite(brief.subject, language: language)
            brief.angle = DashRewriter.rewrite(brief.angle, language: language)
            brief.openingLine = DashRewriter.rewrite(brief.openingLine, language: language)
            idea.brief = brief
        }
        return idea
    }

    /// The opening line without the creator's catchphrase in front of it (`CatchphraseTrim`).
    static func withoutCatchphrase(_ line: String, phrases: [String]) -> String {
        CatchphraseTrim.trimmingLeading(line, phrases: phrases)
    }

    /// One line, without markdown, wrapping quotes, dashes or the label of the field ("Opening line: …"); `language` is a minimal identifier.
    static func clean(_ raw: String, labels: [String], language: String? = nil) -> String {
        let language = language.map(Locale.Language.init(identifier:))
        var line = ScriptPromptBuilder.cleanTitle(raw, language: language)
        for label in labels {
            guard line.lowercased().hasPrefix(label) else { continue }
            // "Angle — …" has become "Angle: …" (French puts a space before the colon).
            let rest = line.dropFirst(label.count).drop { $0.isWhitespace }
            guard let first = rest.first, first == ":" || first == "-" || first == "—" else { continue }
            line = ScriptPromptBuilder.cleanTitle(String(rest.dropFirst()), language: language)
            break
        }
        // Quotes the model put around a sentence after taking its label off.
        if line.count >= 2, let first = line.first, let last = line.last, "\"“'«「".contains(first), "\"”'»」".contains(last) {
            line = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return line
    }
}
