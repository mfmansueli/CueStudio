//
//  CommentParser.swift
//  Cue Studio
//

import Foundation

/// Reads a comment out of what Vision found in a screenshot of one: the author's @name if there is one, and the
/// comment without the app's own buttons and times ("Reply", "2h", "View replies"…). It only suggests: the creator
/// confirms every word before anything is written.
nonisolated enum CommentParser {
    struct Parsed: Equatable, Sendable {
        var author: String?
        var text: String
    }

    /// Lines that are the app's own and never part of a comment.
    private static let noise: Set<String> = [
        "reply", "like", "likes", "share", "send", "view replies", "hide replies", "see translation", "translate", "pinned", "author",
        "responder", "curtir", "compartilhar", "répondre", "antworten", "responder", "rispondi",
    ]

    static func parse(_ recognized: String) -> Parsed {
        let lines = recognized.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var author: String?
        var body: [String] = []
        for line in lines {
            if isNoise(line) { continue }
            if author == nil, body.isEmpty, let name = handle(in: line) {
                author = name
                // A handle with the comment after it, on the same line.
                let rest = line.replacingOccurrences(of: name, with: "").trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters))
                if !rest.isEmpty, !isNoise(rest), !isTimestamp(rest) { body.append(rest) }
                continue
            }
            body.append(line)
        }
        return Parsed(author: author, text: body.joined(separator: " "))
    }

    // MARK: - Pieces

    private static func isNoise(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return noise.contains(lowered) || isTimestamp(line) || isCount(lowered)
    }

    /// "2h", "3d", "1 w", "5 min", "now".
    private static func isTimestamp(_ line: String) -> Bool {
        line.lowercased().wholeMatch(of: /(now|\d{1,3}\s?(s|m|min|h|hr|d|w|wk|y|mo)s?)/) != nil
    }

    /// "12 likes", "1.2K".
    private static func isCount(_ line: String) -> Bool {
        line.wholeMatch(of: /[\d.,]+\s?[kKmM]?(\s?(likes|like|replies|reply))?/) != nil
    }

    /// "@maya.costa" at the start of a line (or a single short word that looks like a user name above the comment).
    private static func handle(in line: String) -> String? {
        if let match = line.prefixMatch(of: /@[A-Za-z0-9._]{2,30}/) { return String(line[match.range]) }
        return nil
    }
}
