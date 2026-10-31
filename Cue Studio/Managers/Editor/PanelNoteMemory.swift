//
//  PanelNoteMemory.swift
//  Cue Studio
//

import Foundation

/// The editor's teaching notes (how a gesture works, where something lives) that the creator has already read. Each one shows the first
/// `lessons` times its panel opens, then stays away; the notes about a consequence ("0% keeps it muted under your voice") always show
/// (`PanelNote(teaches:)`, decision of 30/10/2026: about 40 of the 72 notes were fixed tutorials). Kept on this iPhone, by the note's words:
/// a note reworded, or the app in another language, teaches again.
@MainActor
@Observable
final class PanelNoteMemory {
    /// How many times a teaching note shows before it goes.
    static let lessons = 3

    private var reads: [String: Int]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reads = defaults.dictionary(forKey: DefaultsKey.panelNotesRead) as? [String: Int] ?? [:]
    }

    /// The note still has something to teach: it was shown fewer than `lessons` times.
    func teaches(_ note: String) -> Bool {
        reads[Self.key(note), default: 0] < Self.lessons
    }

    /// The note was shown once more (its panel opened with it).
    func read(_ note: String) {
        let key = Self.key(note)
        guard reads[key, default: 0] < Self.lessons else { return }
        reads[key, default: 0] += 1
        defaults.set(reads, forKey: DefaultsKey.panelNotesRead)
    }

    private static func key(_ note: String) -> String { FactReview.digest(of: note) }
}
