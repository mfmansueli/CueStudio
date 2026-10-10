//
//  IdeaBriefReader.swift
//  Cue Studio
//

import Foundation

/// The model's ideas as the card and Find inspiration show them. Pure text, so it is tested without the model: each answer is cleaned (markdown,
/// wrapping quotes, a label like "Angle:" the model wrote out), matched to the slot it was asked for (the slot says the angle, the topic and so the
/// kind of video; the model's own word for either is not trusted), and fitted to the composer (`IdeaBrief.fitted`). An answer without a title or
/// an opening line is no idea and is dropped.
nonisolated enum IdeaBriefReader {
    /// One idea as the model wrote it.
    struct Answer: Sendable {
        var title: String
        var angle: String
        var openingLine: String
    }

    /// The ideas of a batch, in the slots' order; `language` is the one they were asked in (a minimal identifier).
    static func ideas(from answers: [Answer], slots: [IdeaSlot], language: String?) -> [ThemeIdea] {
        zip(answers, slots).compactMap { answer, slot in idea(from: answer, slot: slot, language: language) }
    }

    static func idea(from answer: Answer, slot: IdeaSlot, language: String?) -> ThemeIdea? {
        let title = clean(answer.title, labels: ["title"])
        let angle = clean(answer.angle, labels: ["angle", "your angle"])
        let opening = clean(answer.openingLine, labels: ["opening line", "opening", "hook", "open with"])
        guard !title.isEmpty, !opening.isEmpty else { return nil }
        var idea = ThemeIdea(
            title: title, kind: slot.angle.kind, length: length(for: slot.angle), niche: slot.topic.niche ?? .lifestyle,
            topic: slot.topic.niche == nil ? slot.topic.label : nil
        )
        idea.angle = slot.angle.rawValue
        idea.brief = IdeaBrief(
            subject: title, angle: angle, openingLine: opening, subtopic: subtopic(of: slot.topic, in: [title, angle, opening], language: language),
            language: language, angleKind: slot.angle.rawValue, topicKey: IdeaTaste.topicKey(of: slot.topic)
        ).fitted()
        // The headline the card shows is the brief's, cut the same way.
        idea.title = idea.brief?.subject ?? title
        return idea
    }

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

    /// One line, without markdown, wrapping quotes or the label of the field ("Opening line: …").
    static func clean(_ raw: String, labels: [String]) -> String {
        var line = ScriptPromptBuilder.cleanTitle(raw)
        for label in labels {
            guard line.lowercased().hasPrefix(label) else { continue }
            let rest = line.dropFirst(label.count)
            guard let first = rest.first, first == ":" || first == "-" || first == "—" else { continue }
            line = ScriptPromptBuilder.cleanTitle(String(rest.dropFirst()))
            break
        }
        // Quotes the model put around a sentence after taking its label off.
        if line.count >= 2, let first = line.first, let last = line.last, "\"“'«「".contains(first), "\"”'»」".contains(last) {
            line = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return line
    }
}
