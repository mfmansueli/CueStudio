//
//  StyleLibrary.swift
//  Cue Studio
//

import Foundation

/// A creator's own styles of one kind (captions, texts or covers), in the order they made them, with the ones they favor
/// (theirs and Cue's alike) and the one new work starts in. Pure: the panels change it through these operations, and
/// `TextStyleStoring` keeps it between launches.
nonisolated struct StyleLibrary<Look: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    /// The longest a style's name may be.
    static var nameLimit: Int { 40 }

    var styles: [SavedStyle<Look>] = []
    var favorites: Set<StyleKey> = []
    /// What new work starts in; nil: Cue's own start.
    var defaultStyle: StyleKey?

    init(styles: [SavedStyle<Look>] = [], favorites: Set<StyleKey> = [], defaultStyle: StyleKey? = nil) {
        self.styles = styles
        self.favorites = favorites
        self.defaultStyle = defaultStyle
    }

    /// A style taken out, with what it was, so Undo puts it back as it was.
    struct Removal: Hashable, Sendable {
        let style: SavedStyle<Look>
        let index: Int
        let wasFavorite: Bool
        let wasDefault: Bool
    }

    func style(_ id: UUID) -> SavedStyle<Look>? {
        styles.first { $0.id == id }
    }

    /// The saved style new work starts in, when the default is one of the creator's.
    var defaultSaved: SavedStyle<Look>? {
        defaultStyle?.savedID.flatMap(style)
    }

    func isFavorite(_ key: StyleKey) -> Bool { favorites.contains(key) }

    func isDefault(_ key: StyleKey) -> Bool { defaultStyle == key }

    // MARK: - Changing it

    /// Saves `look` as a new style named `name` (trimmed, at most `nameLimit` letters; empty: the next "My style N").
    @discardableResult
    mutating func add(_ look: Look, named name: String, at date: Date = .now) -> SavedStyle<Look> {
        let style = SavedStyle(name: cleaned(name) ?? nextName(), look: look, at: date)
        styles.append(style)
        return style
    }

    mutating func rename(_ id: UUID, to name: String) {
        guard let index = styles.firstIndex(where: { $0.id == id }), let name = cleaned(name) else { return }
        styles[index].name = name
    }

    /// The style now looks like `look` (videos already made keep theirs).
    mutating func update(_ id: UUID, with look: Look, at date: Date = .now) {
        guard let index = styles.firstIndex(where: { $0.id == id }) else { return }
        styles[index].look = look
        styles[index].updatedAt = date
    }

    /// A copy right after it, named "<name> copy".
    @discardableResult
    mutating func duplicate(_ id: UUID, at date: Date = .now) -> SavedStyle<Look>? {
        guard let index = styles.firstIndex(where: { $0.id == id }) else { return nil }
        let copy = SavedStyle(name: copyName(of: styles[index].name), look: styles[index].look, at: date)
        styles.insert(copy, at: index + 1)
        return copy
    }

    mutating func toggleFavorite(_ key: StyleKey) {
        if favorites.contains(key) { favorites.remove(key) } else { favorites.insert(key) }
    }

    /// New work starts in `key` (nil: Cue's own start).
    mutating func setDefault(_ key: StyleKey?) {
        defaultStyle = key
    }

    /// Takes the style out (and its favorite and default with it), returning what Undo needs.
    mutating func remove(_ id: UUID) -> Removal? {
        guard let index = styles.firstIndex(where: { $0.id == id }) else { return nil }
        let style = styles.remove(at: index)
        let removal = Removal(style: style, index: index, wasFavorite: favorites.contains(style.key), wasDefault: defaultStyle == style.key)
        favorites.remove(style.key)
        if removal.wasDefault { defaultStyle = nil }
        return removal
    }

    /// Puts a removed style back where it was, favorite and default as they were.
    mutating func restore(_ removal: Removal) {
        guard style(removal.style.id) == nil else { return }
        styles.insert(removal.style, at: min(removal.index, styles.count))
        if removal.wasFavorite { favorites.insert(removal.style.key) }
        if removal.wasDefault { defaultStyle = removal.style.key }
    }

    // MARK: - Names

    /// "My style", then "My style 2", "My style 3"… whichever is free.
    func nextName() -> String {
        let base = String(localized: "My style")
        let taken = Set(styles.map(\.name))
        guard taken.contains(base) else { return base }
        let number = (2...).first { !taken.contains(String(localized: "My style \($0)")) } ?? styles.count + 1
        return String(localized: "My style \(number)")
    }

    private func copyName(of name: String) -> String {
        let taken = Set(styles.map(\.name))
        let first = String(localized: "\(name) copy", comment: "A duplicated style's name")
        guard taken.contains(first) else { return String(first.prefix(Self.nameLimit)) }
        let number = (2...).first { !taken.contains(String(localized: "\(name) copy \($0)", comment: "A duplicated style's name")) } ?? 2
        return String(String(localized: "\(name) copy \(number)", comment: "A duplicated style's name").prefix(Self.nameLimit))
    }

    private func cleaned(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(Self.nameLimit))
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case styles, favorites, defaultStyle
    }

    /// A style or a key this version can't read is left out, never the whole library.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        styles = container.decodeLossy([SavedStyle<Look>].self, forKey: .styles)
        favorites = Set(container.decodeLossy([StyleKey].self, forKey: .favorites))
        defaultStyle = try? container.decodeIfPresent(StyleKey.self, forKey: .defaultStyle)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(styles, forKey: .styles)
        try container.encode(favorites.sorted { $0.identifier < $1.identifier }, forKey: .favorites)
        try container.encodeIfPresent(defaultStyle, forKey: .defaultStyle)
    }
}
