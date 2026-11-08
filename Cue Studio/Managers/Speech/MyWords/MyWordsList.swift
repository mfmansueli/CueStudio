//
//  MyWordsList.swift
//  Cue Studio
//

import Foundation

/// My words: the names and terms a creator says often (their brand, the people they mention, their field's jargon), written the
/// way they want them, so speech recognition listens for them in new captions and recordings (`RecognitionHints`). A list of its
/// own on this iPhone: never the AI writing profile (My Cue Voice), and never a change to a video already captioned.
///
/// Words are kept as typed, newest first. Two spellings of the same word (capitals or full/half width aside) are one entry: adding
/// it again with other capitals saves the new spelling in its place. Accents count ("cafe" and "café" are two words), as in Find
/// and replace.
nonisolated struct MyWordsList: Equatable, Sendable {
    /// Most entries kept. Recognition takes at most `RecognitionHints.limit` hints, and the script's names still need room beside
    /// these.
    static let limit = 50
    /// Longest entry, in characters: a name or a short phrase ("Cue Studio"), never a sentence.
    static let longest = 40

    /// What adding a word did.
    enum Addition: Equatable, Sendable {
        /// Saved as a new entry.
        case added(String)
        /// Already there with other capitals: saved with this spelling in its place.
        case respelled(String)
        /// Already there, spelled the same.
        case alreadyThere(String)
        /// The list holds `limit` words.
        case full
        /// Nothing to save: empty, or longer than `longest`.
        case invalid
    }

    /// The words, newest first.
    private(set) var words: [String]

    /// A list of `words` as they would be after adding each one in turn from the last: cleaned, without repeats or empty entries,
    /// at most `limit`. Reads whatever was stored, so a damaged list never brings back an entry that couldn't be added.
    init(_ words: [String] = []) {
        var kept: [String] = []
        var seen = Set<String>()
        for word in words {
            let cleaned = Self.cleaned(word)
            guard Self.isValid(cleaned), seen.insert(Self.key(cleaned)).inserted else { continue }
            kept.append(cleaned)
            if kept.count == Self.limit { break }
        }
        self.words = kept
    }

    var isEmpty: Bool { words.isEmpty }
    var count: Int { words.count }

    /// The entry spelled like `text` (capitals aside), if there is one.
    func entry(matching text: String) -> String? {
        let key = Self.key(Self.cleaned(text))
        return words.first { Self.key($0) == key }
    }

    // MARK: - Changes

    /// Saves `text` (cleaned) at the top of the list.
    @discardableResult
    mutating func add(_ text: String) -> Addition {
        let word = Self.cleaned(text)
        guard Self.isValid(word) else { return .invalid }
        if let index = index(of: word) {
            guard words[index] != word else { return .alreadyThere(word) }
            words[index] = word
            return .respelled(word)
        }
        guard words.count < Self.limit else { return .full }
        words.insert(word, at: 0)
        return .added(word)
    }

    /// `old` written as `text` instead, in its place. Typed as another entry's word, the two become one. Nil when `old` isn't in
    /// the list or `text` can't be saved (the list stays as it was).
    @discardableResult
    mutating func change(_ old: String, to text: String) -> String? {
        let word = Self.cleaned(text)
        guard Self.isValid(word), let index = words.firstIndex(of: old) else { return nil }
        if let other = self.index(of: word), other != index {
            words[other] = word
            words.remove(at: index)
        } else {
            words[index] = word
        }
        return word
    }

    mutating func remove(_ word: String) {
        words.removeAll { $0 == word }
    }

    mutating func remove(atOffsets offsets: IndexSet) {
        words = words.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
    }

    // MARK: - Spelling

    /// `text` as it is saved: spaces at the ends dropped, runs of spaces and line breaks inside folded to one space, and the
    /// quotation marks around it (a word copied with them) taken off. Capitals, accents and other marks stay ("C#", "Node.js").
    static func cleaned(_ text: String) -> String {
        let quotes = CharacterSet(charactersIn: "\"'“”‘’«»„‚「」『』")
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return words.joined(separator: " ").trimmingCharacters(in: quotes.union(.whitespaces))
    }

    /// Whether a cleaned text can be saved: not empty, at most `longest` characters.
    static func isValid(_ cleaned: String) -> Bool {
        !cleaned.isEmpty && cleaned.count <= longest
    }

    /// What two spellings of one word share: capitals and full/half width folded, accents kept.
    static func key(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
    }

    private func index(of word: String) -> Int? {
        let key = Self.key(word)
        return words.firstIndex { Self.key($0) == key }
    }
}
