//
//  VoiceSampleBuilder.swift
//  Cue Studio
//

import Foundation

/// The sample script of the preview, the same idea ("three habits for better mornings") written two ways: plain, as most scripts read, and in the creator's
/// voice, put together from what they answered: who is talking ("I" or "we"), how they open and the first words they say, their tone, how much the audience
/// knows, how long their sentences are, their energy and humor, how they end and why people watch. Deterministic, so the preview changes only when the voice
/// does; it is a sample of the voice, never the scripts Cue writes (those are written by the model).
nonisolated enum VoiceSampleBuilder {
    /// The same idea with no voice on it.
    static func plain() -> VoiceSample {
        VoiceSample(
            hook: String(localized: "Mornings can be challenging, but there are good habits that can help you start the day."),
            body: String(localized: "Consider limiting phone use, drinking water and setting goals for the day."),
            cta: String(localized: "Follow for more tips!")
        )
    }

    static func sample(for profile: CreatorProfile) -> VoiceSample {
        let speaksAsWe = profile.resolvedSpeaksAs == .we
        var hook = [catchphrase(of: profile), opening(for: profile)].compactMap { $0 }.joined(separator: " ")
        var body = bodyLine(for: profile)
        var cta = ending(for: profile)
        if speaksAsWe {
            hook = asWe(hook)
            body = asWe(body)
            cta = asWe(cta)
        }
        if profile.style.energy == .high, hook.hasSuffix(".") { hook = String(hook.dropLast()) + "!" }
        return VoiceSample(hook: hook, body: body, cta: cta, tags: tags(for: profile, speaksAsWe: speaksAsWe))
    }

    // MARK: - Hook

    private static func catchphrase(of profile: CreatorProfile) -> String? {
        guard let phrase = profile.phrases.first else { return nil }
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return nil }
        return ".!?".contains(last) ? trimmed : trimmed + "."
    }

    /// The way they open when they chose one; else a line of their tone.
    private static func opening(for profile: CreatorProfile) -> String {
        if let stored = profile.openings.first, case .known(let id, _) = VoiceChoiceCatalog.opening(stored) {
            switch id {
            case "Bold claim": return String(localized: "Your mornings aren’t broken. Your first ten minutes are.")
            case "Question": return String(localized: "Why do some mornings feel like a fight?")
            case "Story opener": return String(localized: "I used to hit snooze four times. Then I tried this.")
            case "Surprising fact": return String(localized: "Most people check their phone within a minute of waking up.")
            case "POV": return String(localized: "POV: you finally stopped losing your mornings.")
            case "Mistake to avoid": return String(localized: "Stop doing this the second you wake up.")
            default: return String(localized: "Three small habits changed how my mornings feel.")
            }
        }
        return toneLine(for: profile.sounds.first, isChosen: profile.isChosen(.tone))
    }

    private static func toneLine(for sound: VoiceSound?, isChosen: Bool) -> String {
        switch isChosen ? sound : nil {
        case .professional?: String(localized: "Three habits. Ten minutes. Better mornings.")
        case .educational?: String(localized: "Here’s why your first ten minutes decide your day.")
        case .confident?: String(localized: "This is the morning routine I trust. No exceptions.")
        case .warmCalm?: String(localized: "Let’s make mornings a little softer, okay?")
        case .energetic?: String(localized: "Quick one — three habits that changed everything!")
        case .funny?: String(localized: "My alarm and I were not friends. Then this happened.")
        case .dry?: String(localized: "Great, another morning routine. Except this one works.")
        case .casual?, nil: String(localized: "I used to hit snooze four times. Then I tried this.")
        }
    }

    // MARK: - Body

    /// The three steps, worded for how much the audience knows and joined the way their sentences run.
    private static func bodyLine(for profile: CreatorProfile) -> String {
        let steps: [String] = switch profile.audienceLevel ?? .new {
        case .new: [
            String(localized: "No phone for the first twenty minutes."),
            String(localized: "Water before coffee."),
            String(localized: "Write down one thing that would make today a win."),
        ]
        case .some: [
            String(localized: "Twenty screen-free minutes protect your focus."),
            String(localized: "Hydrate before caffeine — it hits better."),
            String(localized: "Pick one priority, not five."),
        ]
        case .experienced: [
            String(localized: "Protect the first 20 minutes from inputs."),
            String(localized: "Hydrate before caffeine."),
            String(localized: "Lock one priority before email."),
        ]
        }
        var line: String
        switch profile.style.sentences ?? .short {
        case .long:
            line = [withoutStop(steps[0]), withoutStop(lowercasedFirst(steps[1])), lowercasedFirst(steps[2])].joined(separator: ", ")
        case .mixed:
            line = steps[0] + " " + withoutStop(steps[1]) + ", " + lowercasedFirst(steps[2])
        case .short:
            line = steps.joined(separator: " ") + " " + String(localized: "That’s it.")
        }
        if profile.reach.humor == .lot { line += " " + String(localized: "Yes, even before coffee. I know.") }
        return line
    }

    private static func withoutStop(_ text: String) -> String {
        text.hasSuffix(".") ? String(text.dropLast()) : text
    }

    private static func lowercasedFirst(_ text: String) -> String {
        text.prefix(1).lowercased() + text.dropFirst()
    }

    // MARK: - Ending

    private static func ending(for profile: CreatorProfile) -> String {
        if let stored = profile.endings.first {
            switch VoiceChoiceCatalog.ending(stored) {
            case .known(let id, _):
                switch id {
                case "Save this": return String(localized: "Save this for tomorrow morning.")
                case "Follow for more": return String(localized: "Follow for part two tomorrow.")
                case "Comment your answer": return String(localized: "Which one are you trying first? Tell me below.")
                case "Link in bio": return String(localized: "My full routine is in the link in bio.")
                case "Try it and tell me": return String(localized: "Try one tomorrow and tell me how it felt.")
                default: return ""
                }
            case .typed(let text): return text
            }
        }
        switch profile.watchReasons.first ?? .learn {
        case .learn: return String(localized: "Save this for tomorrow morning.")
        case .getInspired: return String(localized: "Try one tomorrow and tell me how it felt.")
        case .solveProblem: return String(localized: "Start with number one tonight.")
        case .laugh: return String(localized: "Tell me your snooze count below.")
        case .feelUnderstood: return String(localized: "If mornings are hard for you too, you’re not alone.")
        case .decideToBuy: return String(localized: "Everything I use is under 10 dollars.")
        }
    }

    // MARK: - "We"

    /// "I" and "my" turned into "we" and "our", the way a team says it (the prototype's own rule), keeping the capital at the start of a sentence.
    private static func asWe(_ text: String) -> String {
        var result = text
        for (from, to) in [("\\bI\\b", "we"), ("\\bmy\\b", "our"), ("\\bMy\\b", "Our")] {
            result = result.replacingOccurrences(of: from, with: to, options: .regularExpression)
        }
        // A sentence starts with a capital.
        var capitalized = ""
        var atStart = true
        for character in result {
            capitalized.append(atStart && character.isLetter ? Character(character.uppercased()) : character)
            if character.isLetter || character.isNumber { atStart = false }
            if ".!?—:".contains(character) { atStart = true }
        }
        return capitalized
    }

    // MARK: - Tags

    private static func tags(for profile: CreatorProfile, speaksAsWe: Bool) -> [String] {
        var tags = [speaksAsWe ? String(localized: "says “we”") : String(localized: "says “I”")]
        if profile.isChosen(.tone), let sound = profile.sounds.first { tags.append(sound.label.lowercased()) }
        if let level = profile.audienceLevel { tags.append(level.label.lowercased()) }
        if let topic = profile.topics.first { tags.append(topic.label.lowercased()) }
        if let stored = profile.openings.first { tags.append(String(localized: "\(stored.lowercased()) hook")) }
        if let ending = profile.endings.first { tags.append(String(localized: "ends: \(ending.lowercased())")) }
        return tags
    }
}
