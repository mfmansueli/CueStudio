//
//  VoiceChoiceCatalog.swift
//  Cue Studio
//

import Foundation
import Synchronization

/// What an opening style or an ending the creator picked asks of the AI, whatever language it was picked in. They are kept as the words
/// the creator saw ("Pregunta", "Question"), so the catalog finds them again in every language the app has, and what it doesn't know (typed
/// by the creator) is passed on as it is.
nonisolated enum VoiceChoiceCatalog {
    /// The English id of each opening style and what it asks of the script.
    static let openings: [(id: String, guidance: String)] = [
        ("Bold claim", "a bold claim"),
        ("Question", "a question"),
        ("Story opener", "the start of a short story"),
        ("Surprising fact", "a surprising fact"),
        ("POV", "a POV line (“POV: …”)"),
        ("Mistake to avoid", "a common mistake to avoid"),
        ("Start with a number", "a specific number"),
    ]

    /// The English id of each ending and what it asks of the script.
    static let endings: [(id: String, guidance: String)] = [
        ("Save this", "asking viewers to save the video"),
        ("Follow for more", "inviting them to follow for more"),
        ("Comment your answer", "asking them to comment their answer"),
        ("Link in bio", "pointing to the link in bio"),
        ("Try it and tell me", "asking them to try it and tell the creator how it went"),
        ("No call to action", "leaving out any call to action"),
    ]

    /// The guidance for a stored opening, or the creator's own words.
    static func opening(_ stored: String) -> Choice {
        choice(stored, in: openings)
    }

    /// The guidance for a stored ending, or the creator's own words.
    static func ending(_ stored: String) -> Choice {
        choice(stored, in: endings)
    }

    /// What an ending asks of the script, as something to do: "asking viewers to save the video", or `saying “See you Sunday”` for a typed one.
    static func endingAction(_ stored: String) -> String {
        switch ending(stored) {
        case .known(_, let guidance): guidance
        case .typed(let text): "saying “\(text)”"
        }
    }

    /// What a stored answer means to the AI.
    enum Choice: Hashable, Sendable {
        /// One of Cue's: the English id (what the script must not say) and what to do.
        case known(id: String, guidance: String)
        /// The creator's own words.
        case typed(String)

        var guidance: String {
            switch self {
            case .known(_, let guidance): guidance
            case .typed(let text): "“\(text)”"
            }
        }

        /// Words that must never open the script as they are (the label of a style Cue offered).
        var labels: [String] {
            switch self {
            case .known(let id, _): [id]
            case .typed: []
            }
        }
    }

    private static func choice(_ stored: String, in list: [(id: String, guidance: String)]) -> Choice {
        guard let id = key(matching: stored, among: list.map(\.id)), let match = list.first(where: { $0.id == id }) else {
            return .typed(stored)
        }
        return .known(id: match.id, guidance: match.guidance)
    }

    // MARK: - Matching across languages

    /// The English id `stored` is one of `ids` in, in any language the app has; nil when it isn't one.
    static func key(matching stored: String, among ids: [String]) -> String? {
        let wanted = VoiceTextValidator.key(stored)
        return ids.first { VoiceTextValidator.key($0) == wanted || translations(of: $0).contains(wanted) }
    }

    private static let cache = Mutex<[String: Set<String>]>([:])

    /// What the interface says for `id` in every language of the app, as `VoiceTextValidator.key`s.
    static func translations(of id: String) -> Set<String> {
        if let cached = cache.withLock({ $0[id] }) { return cached }
        var found: Set<String> = []
        for localization in Bundle.main.localizations where localization != "Base" {
            guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: localization),
                  let table = NSDictionary(contentsOfFile: path) as? [String: String], let text = table[id] else { continue }
            found.insert(VoiceTextValidator.key(text))
        }
        cache.withLock { $0[id] = found }
        return found
    }
}
