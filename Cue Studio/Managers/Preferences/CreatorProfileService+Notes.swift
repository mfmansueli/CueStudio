//
//  CreatorProfileService+Notes.swift
//  Cue Studio
//

import Foundation

/// "Also true about me" (the owner's item 7, 02/11/2026): the creator adds, changes and removes the notes in their own words that no question
/// has a place for (`CreatorProfile.notes`).
extension CreatorProfileService {
    @discardableResult
    func addNote(_ raw: String) -> VoiceEditResult {
        store(raw, replacing: nil)
    }

    /// Changes `note` in place; an empty text removes it.
    @discardableResult
    func replaceNote(_ note: String, with raw: String) -> VoiceEditResult {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            removeNote(note)
            return .removed
        }
        return store(raw, replacing: note)
    }

    func removeNote(_ note: String) {
        let key = VoiceTextValidator.key(note)
        var updated = profile
        updated.customTags.removeAll { VoiceTextValidator.key($0) == key }
        profile = updated
    }

    private func store(_ raw: String, replacing note: String?) -> VoiceEditResult {
        var updated = profile
        let index = note.flatMap { old in updated.customTags.firstIndex { VoiceTextValidator.key($0) == VoiceTextValidator.key(old) } }
        var others = updated.customTags
        if let index { others.remove(at: index) }
        // Checked with no list: a note can't be a typo of an option.
        switch VoiceTextValidator.check(raw, existing: others) {
        case .duplicate: return .alreadyThere
        case .accepted(let text):
            if let index { updated.customTags[index] = text } else { updated.customTags.append(text) }
            profile = updated
            return .added
        case let check: return .rejected(check)
        }
    }
}
