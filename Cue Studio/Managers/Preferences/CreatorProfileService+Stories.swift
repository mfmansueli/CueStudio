//
//  CreatorProfileService+Stories.swift
//  Cue Studio
//

import Foundation

/// What became of a story the creator told.
enum VoiceStoryResult: Equatable {
    case added
    /// Too little to be a moment (a word or two).
    case tooShort
    /// Words the model won't learn from.
    case blocked
    case limit
}

extension CreatorProfileService {
    // MARK: - Stories and facts (the owner's item 9, 02/11/2026)

    /// The shortest a story can be: a sentence, not a word.
    static let shortestStory = 15

    /// A true moment, said or typed, under its question; the text is kept as told, up to `VoiceStory.maxCharacters`.
    @discardableResult
    func addStory(_ raw: String, kind: VoiceStory.Kind, said: Bool = false) -> VoiceStoryResult {
        let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(VoiceStory.maxCharacters))
        guard text.count >= Self.shortestStory else { return .tooShort }
        guard !VoiceTextValidator.isBlocked(text) else { return .blocked }
        guard profile.stories.count < VoiceStory.limit else { return .limit }
        var updated = profile
        updated.stories.append(VoiceStory(kind: kind, text: text, said: said))
        profile = updated
        return .added
    }

    func removeStory(_ id: UUID) {
        profile.stories.removeAll { $0.id == id }
    }

    /// "I may name this person", for a client's result.
    func setMayName(_ mayName: Bool, story id: UUID) {
        guard let index = profile.stories.firstIndex(where: { $0.id == id }) else { return }
        profile.stories[index].mayName = mayName
    }
}
