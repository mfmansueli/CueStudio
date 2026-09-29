//
//  ScriptType+Brief.swift
//  Cue Studio
//

import Foundation

/// The brief each format asks for, and the structured draft Cue builds from it. The draft is the
/// fallback when the on-device model is unavailable, and the structure the model is asked to follow.
nonisolated extension ScriptType {
    var briefFields: [BriefField] {
        switch self {
        case .ad:
            [
                BriefField(key: "brand", label: String(localized: "Brand & product"), example: String(localized: "Oat & Co. barista oat milk")),
                BriefField(key: "pain", label: String(localized: "Problem it solves"), example: String(localized: "Oat milk that never foams")),
                BriefField(key: "benefit", label: String(localized: "Main benefit"), example: String(localized: "Foams like dairy, zero aftertaste")),
                BriefField(key: "proof", label: String(localized: "Show it working"), example: String(localized: "A latte-art pour on camera")),
                BriefField(key: "offer", label: String(localized: "Code or link"), example: String(localized: "Code MORNING for 20% off")),
            ]
        case .review:
            [
                BriefField(key: "product", label: String(localized: "Product"), example: String(localized: "Lumen desk lamp")),
                BriefField(key: "first", label: String(localized: "First impression"), example: String(localized: "Heavier than it looks and folds flat")),
                BriefField(key: "pro", label: String(localized: "Best thing"), example: String(localized: "Flicker-free light on camera")),
                BriefField(key: "con", label: String(localized: "Worst thing"), example: String(localized: "Pricey for a lamp")),
                BriefField(key: "verdict", label: String(localized: "Verdict"), example: String(localized: "Worth it if you film at a desk")),
            ]
        case .tutorial:
            [
                BriefField(key: "topic", label: String(localized: "What you're teaching"), example: String(localized: "Batch-filming a week of content")),
                BriefField(key: "result", label: String(localized: "What they'll get"), example: String(localized: "Five videos from one afternoon")),
                BriefField(key: "steps", label: String(localized: "Steps, separated by commas"), example: String(localized: "Plan the hooks, pick one outfit, set one light, film in order")),
            ]
        case .list:
            [
                BriefField(key: "topic", label: String(localized: "Topic"), example: String(localized: "Morning habits")),
                BriefField(key: "items", label: String(localized: "Your points, separated by commas"), example: String(localized: "No phone for 20 minutes, write one goal, move for 5 minutes")),
            ]
        case .story:
            [
                BriefField(key: "setup", label: String(localized: "What happened"), example: String(localized: "My first brand call — and my camera froze")),
                BriefField(key: "twist", label: String(localized: "The twist"), example: String(localized: "They said it was the most real pitch all week")),
                BriefField(key: "payoff", label: String(localized: "How it ended"), example: String(localized: "We signed a three-month deal")),
            ]
        case .opinion:
            [
                BriefField(key: "take", label: String(localized: "Your take"), example: String(localized: "You don't need expensive gear")),
                BriefField(key: "why", label: String(localized: "Why you think so"), example: String(localized: "Viewers remember your first sentence, not your camera")),
                BriefField(key: "ask", label: String(localized: "Question for the comments"), example: String(localized: "What's one thing you can't film without?")),
            ]
        case .launch:
            [
                BriefField(key: "news", label: String(localized: "The news"), example: String(localized: "My first preset pack")),
                BriefField(key: "when", label: String(localized: "When"), example: String(localized: "Drops Friday at 9 a.m.")),
                BriefField(key: "details", label: String(localized: "Key detail"), example: String(localized: "12 presets made for phone footage")),
                BriefField(key: "cta", label: String(localized: "What to do next"), example: String(localized: "Join the waitlist — link in bio")),
            ]
        case .apology:
            [
                BriefField(key: "what", label: String(localized: "What this is about"), example: String(localized: "Last week's giveaway video")),
                BriefField(key: "impact", label: String(localized: "Who it affected and how"), example: String(localized: "Some of you felt misled")),
                BriefField(key: "own", label: String(localized: "What you take responsibility for"), example: String(localized: "I should have said up front that it was sponsored")),
                BriefField(key: "change", label: String(localized: "What changes now"), example: String(localized: "Every paid post will be clearly labeled from now on")),
            ]
        }
    }

    var briefTip: String {
        switch self {
        case .ad: String(localized: "Bullets are enough. Open with your usual greeting, hit the product with one strong line, show it working in the middle, close with the code.")
        case .review: String(localized: "Say it like you would to a friend: one line on first impressions, one thing you love, one thing you don't, and a clear yes or no.")
        case .tutorial: String(localized: "List the steps in plain words, separated by commas. Cue turns them into a numbered walkthrough with a hook up top and a save-this ending.")
        case .list: String(localized: "Just the topic and your points. Cue writes a numbered list with a hook up top and a comment prompt at the end.")
        case .story: String(localized: "Three beats are enough: what happened, the moment it turned, how it ended. Cue adds a cliffhanger hook and pacing cues.")
        case .opinion: String(localized: "State the opinion in one line, give one reason, end with a question — questions drive comments.")
        case .launch: String(localized: "Lead with the news, not the backstory. Add when it happens and one detail that makes people care.")
        case .apology: String(localized: "Be specific and brief. Name what happened, own it without a “but”, and say what changes. Cue removes hype, jokes and calls to action.")
        }
    }

    /// Extra rule shown for serious formats.
    var briefNote: String? {
        self == .apology ? String(localized: "Serious mode: no hooks, jokes, hype or “follow for more”.") : nil
    }

    /// Brief values with blanks replaced by the examples and trailing punctuation removed, so the
    /// sentences built around them stay clean.
    func resolvedBrief(_ values: [String: String]) -> [String: String] {
        var resolved: [String: String] = [:]
        for field in briefFields {
            let typed = (values[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let value = typed.isEmpty ? field.example : typed
            resolved[field.key] = value.trimmingCharacters(in: CharacterSet(charactersIn: ".!").union(.whitespaces))
        }
        return resolved
    }

    /// The draft's title, in the language the draft is written in (nil: the interface's).
    func draftTitle(from values: [String: String], language: CueLanguage? = nil) -> String {
        let f = resolvedBrief(values)
        let v = { (key: String) in f[key] ?? "" }
        switch self {
        case .ad:
            let brand = v("brand").split(whereSeparator: { "—,.".contains($0) }).first.map(String.init) ?? v("brand")
            return String(localized: "\(brand.trimmingCharacters(in: .whitespaces)) — sponsored", writtenIn: language)
        case .review:
            return String(localized: "\(v("product")) — honest review", writtenIn: language)
        case .tutorial:
            return v("topic")
        case .list:
            let count = Self.commaList(v("items")).count
            return String(localized: "\(count) \(v("topic").lowercased()) that work", writtenIn: language)
        case .story:
            let setup = v("setup").components(separatedBy: " — ").first ?? v("setup")
            return String(localized: "Storytime: \(setup.lowercased())", writtenIn: language)
        case .opinion:
            return String(localized: "Hot take: \(v("take").lowercased())", writtenIn: language)
        case .launch:
            return String(localized: "\(v("news")) — announcement", writtenIn: language)
        case .apology:
            return String(localized: "A note about \(v("what").lowercased())", writtenIn: language)
        }
    }

    /// A structured first draft built only from the brief, written in `language` (nil: the
    /// interface's), cues included. Paragraphs are separated by blank lines.
    func draft(from values: [String: String], language: CueLanguage? = nil) -> String {
        let f = resolvedBrief(values)
        let v = { (key: String) in f[key] ?? "" }
        let lc = { (key: String) in Self.lowercasedFirst(v(key)) }
        let say = { (text: String.LocalizationValue) in
            String(localized: text, writtenIn: language, comment: "A line of a script draft built from a brief. Words in [brackets] are stage cues: translate them too.")
        }
        let paragraphs: [String]
        switch self {
        case .ad:
            paragraphs = [
                say("Okay, I have to tell you about \(v("brand")). [pause]"),
                say("If you've ever dealt with \(lc("pain")), you know the struggle."),
                say("This fixes it. \(v("benefit")). [show product]"),
                say("Watch this — \(lc("proof")). [demo]"),
                say("\(v("offer")) — link in my bio. [look at camera] This video is a paid partnership."),
            ]
        case .review:
            paragraphs = [
                say("I've been testing the \(v("product")). Here's my honest review. [pause]"),
                say("First impression: \(lc("first"))."),
                say("What I love: \(lc("pro")). What I don't: \(lc("con"))."),
                say("Verdict? \(v("verdict")). [look at camera]"),
            ]
        case .tutorial:
            let steps = Self.commaList(v("steps")).enumerated().map { index, step in
                say("Step \(Self.numberWord(index + 1, language: language)): \(Self.lowercasedFirst(step)).")
            }
            paragraphs = [say("Here's how I do \(lc("topic")) — start to finish. [pause]"), say("By the end you'll have \(lc("result")).")]
                + steps
                + [say("Save this so you have it when you need it. [smile]")]
        case .list:
            let items = Self.commaList(v("items"))
            let points = items.enumerated().map { index, item in
                say("Number \(Self.numberWord(index + 1, language: language)): \(Self.lowercasedFirst(item)).")
            }
            paragraphs = [say("\(items.count) \(lc("topic")) that actually changed my life. [pause]")]
                + points
                + [say("Which one are you trying first? Tell me in the comments.")]
        case .story:
            paragraphs = [
                say("Okay, story time. [pause]"),
                "\(v("setup")).",
                say("And then — \(lc("twist")). [beat]"),
                say("\(v("payoff")). [smile]"),
            ]
        case .opinion:
            paragraphs = [
                say("Unpopular opinion: \(lc("take")). [pause]"),
                say("Hear me out."),
                "\(v("why")).",
                say("\(v("ask"))? [look at camera]").replacingOccurrences(of: "??", with: "?"),
            ]
        case .launch:
            paragraphs = [
                say("I've been keeping a secret. [pause]"),
                "\(v("news")) — \(lc("when")).",
                "\(v("details")).",
                say("\(v("cta")). [smile]"),
            ]
        case .apology:
            paragraphs = [
                say("I want to talk about \(lc("what")). [pause]"),
                say("\(v("impact")), and that matters to me."),
                say("\(v("own")). That's on me. [pause]"),
                "\(v("change")).",
                say("Thank you for holding me to a higher standard."),
            ]
        }
        return paragraphs.joined(separator: "\n\n")
    }

    // MARK: - Helpers

    static func commaList(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Lowercases the first letter so a bullet reads well mid-sentence, but keeps "I", acronyms
    /// and names with capitals inside ("TikTok", "USB", "iPhone").
    static func lowercasedFirst(_ text: String) -> String {
        guard let first = text.first, first.isUppercase else { return text }
        let firstWord = text.prefix { !$0.isWhitespace && $0 != "," }
        if firstWord == "I" || firstWord.hasPrefix("I'") || firstWord.hasPrefix("I’") { return text }
        if firstWord.dropFirst().contains(where: \.isUppercase) { return text }
        return first.lowercased() + text.dropFirst()
    }

    /// "one", "dois", "trois": a step number as it's said aloud, in the draft's language (nil:
    /// the interface's). Past ten, the numeral.
    static func numberWord(_ value: Int, language: CueLanguage? = nil) -> String {
        guard (1...10).contains(value) else { return String(value) }
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = language.map { Locale(identifier: $0.interfaceLocalization) } ?? InterfaceLocale.current ?? Locale(identifier: "en")
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
