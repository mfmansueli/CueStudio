//
//  ScriptPromptBuilder+IdeaKitchen.swift
//  Cue Studio
//

import Foundation

/// What Private Cloud Compute is asked around the iPhone model's ideas: the subjects they are made around (`IdeaIngredients`) and the edit
/// that writes them as a native creator would (`IdeaEdits`).
nonisolated extension ScriptPromptBuilder {
    /// What makes the concrete subjects of a topic's videos (`IdeaIngredients`, written by Private Cloud Compute), in `language` as its speakers
    /// write it: Apple's locale phrase first, and the country they live in, so the subjects are of their daily life.
    static func ingredientsInstructions(language: CueLanguage) -> String {
        var lines: [String] = []
        if let locale = localePhrase(language) { lines.append(locale) }
        lines.append("You know what people who watch short talking-head videos care about, in their own country and daily life.")
        if language != .english { lines.append(nativeAnswerRule(language)) }
        return lines.joined(separator: "\n")
    }

    /// One kind's list (`IdeaIngredientList`), each said the way people say it and without its kind's word ("washing meat with lemon", not "the myth
    /// of washing meat with lemon"): the idea's angle already says what it is (`IdeaIngredientKind`). Asked for a place or a time of day with each
    /// situation, the model forced one in ("no ponto à noite"): it is left to it.
    /// - Parameter others: the creator's other topics, which the subjects stay clear of (the subjects of "daily routines" were coffee and bread,
    ///   and its ideas turned into recipes for a creator who also makes cooking videos).
    /// - Parameter creator: who they are and what their videos are for: a nutritionist's food is not a food reviewer's.
    static func ingredientsPrompt(
        _ kind: IdeaIngredientKind, topic: IdeaTopic, others: [IdeaTopic] = [], creator: IdeaCreator? = nil, language: CueLanguage
    ) -> String {
        let name = topic.subtopics.isEmpty ? topic.name : "\(topic.name) (\(topic.subtopics.joined(separator: ", ")))"
        let apart = others.isEmpty ? "" : " Keep to \(topic.name) itself: nothing that belongs more to \(others.map(\.name).joined(separator: " or "))."
        let forWhom = creator?.line(serving: "the subjects").map { " " + $0 } ?? ""
        let people = country(of: language).map { "people in \($0)" } ?? "people"
        let what = switch kind {
        case .belief: "beliefs about \(name) that many \(people) hold and that are wrong or only half true"
        case .mistake: "mistakes \(people) commonly make with \(name), each said as the thing they do"
        case .moment: "everyday situations around \(name) that \(people) have all lived"
        case .thing: "everyday things, kinds of product (never a brand) and habits around \(name) that \(people) know"
        }
        return "List 8 \(what), for a creator who makes short videos about \(name). Write each the way \(people) would say it to a friend: a "
            + "short phrase of two to seven words, never a title or a whole sentence, and never starting with the words myth, mistake, belief or "
            + "error." + apart + forWhom + " No brands, statistics, studies or numbers. Write them in \(language.englishName)."
    }

    /// Who edits the iPhone model's ideas outside English (`IdeaEdits`), on Private Cloud Compute: a native speaker of the creator's country,
    /// told what the small model gets wrong.
    static func ideaEditInstructions(language: CueLanguage) -> String {
        var lines: [String] = []
        if let locale = localePhrase(language) { lines.append(locale) }
        let creator = country(of: language).map { "a creator in \($0)" } ?? "a creator"
        lines.append("You edit the video ideas of \(creator) who films themselves talking to camera. A small model drafted them; it often "
            + "translates English word for word, writes odd phrases, and gives titles that only name the kind of video.")
        lines.append(punctuationRule)
        lines.append(nativeAnswerRule(language))
        return lines.joined(separator: "\n")
    }

    /// The batch to edit, each idea with what it was asked for (its kind, topic and subject), so its idea is kept while its words change.
    static func ideaEditPrompt(
        answers: [IdeaBriefReader.Answer], slots: [IdeaSlot], language: CueLanguage, creator: IdeaCreator? = nil
    ) -> String {
        let native = country(of: language).map { "a creator from \($0)" } ?? "a native creator"
        var prompt = "Edit these \(answers.count) ideas, in the same order. For each, first decide whether to keep it: drop it only when it can't "
            + "be saved, is not about its topic, or nobody would want to watch it. Then write its title, angle and opening line again in natural "
            + "\(language.englishName), as \(native) would post and say them. Keep its kind and its subject; when the draft is vague, confused "
            + "or forgets its subject, write the idea it should have been, around that subject; an idea without a subject may stay broad. The "
            + "title has at most eight words and makes someone want to watch: with a promise, a surprise or a question, the way its kind asks (a "
            + "question asks, a prediction "
            + "predicts), never a flat label like \"tips for\" plus the topic and never the name of its kind; vary their shapes, a question only "
            + "where it fits. The angle is one short sentence that starts with a verb and tells the creator what to do in the video. The opening "
            + "line is the first sentence they say to camera: it hooks from its first words and leads into the angle. " + ideaEditOpeningRule
            + " Each idea stays inside its own topic, unless it is joined with another: then both are in it, meeting naturally. When a draft "
            + "brings in a topic it wasn't joined with, write it about its own topic alone."
        if let line = creator?.promptLine { prompt += " " + line }
        prompt += "\n"
        prompt += zip(answers, slots).enumerated().map { index, pair in
            let (answer, slot) = pair
            let subject = slot.subject.map { " Subject: \($0)." } ?? ""
            let bridge = slot.bridge.map { ", joined with \($0.name) in one idea where the two meet" } ?? ""
            let topic = slot.subtopic.map { "\(slot.topic.name) (\($0))" } ?? slot.topic.name
            return "\(index + 1). Kind: \(slot.angle.ask). Topic: \(topic)\(bridge).\(subject) Title: \(answer.title) "
                + "Angle: \(answer.angle) "
                + "Opening line: \(answer.openingLine)"
        }.joined(separator: "\n")
        return prompt
    }

    /// What the editor may put in the creator's mouth (`IdeaEdits`): the idea is a draft they adjust, so a scene they may have lived is welcome (the
    /// owner's rule of 01/11/2026); a fact that isn't one never is. Held to `openingHonestyRule`, the editor fell back on "Muita gente se
    /// pergunta…" and "On se demande souvent…" in every language.
    static let ideaEditOpeningRule = "An opening line may be a question to the viewer, a surprise, or a moment told in the first person that the "
        + "creator may have lived; never a number, statistic, study, credential or result stated as fact, and never \"many people\" or \"we "
        + "often wonder\". A belief to bust is never stated as true."
}
