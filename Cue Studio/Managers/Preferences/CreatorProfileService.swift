//
//  CreatorProfileService.swift
//  Cue Studio
//

import Foundation

/// The creator's profile ("Creator DNA") and defaults. Stored on the device only.
@MainActor
@Observable
final class CreatorProfileService {
    static let maxPhraseLength = 40

    var profile: CreatorProfile {
        didSet {
            guard let data = try? JSONEncoder().encode(profile) else { return }
            defaults.set(data, forKey: DefaultsKey.creatorProfile)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: DefaultsKey.creatorProfile),
           let stored = try? JSONDecoder().decode(CreatorProfile.self, from: data) {
            profile = stored
        } else {
            profile = CreatorProfile()
        }
    }

    // MARK: - Actions

    func toggleNiche(_ niche: Niche) {
        if let index = profile.niches.firstIndex(of: niche) {
            profile.niches.remove(at: index)
        } else {
            profile.niches.append(niche)
        }
    }

    /// Adds a catchphrase. Returns false when it is empty or already there.
    @discardableResult
    func addPhrase(_ phrase: String) -> Bool {
        let cleaned = String(phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
            .prefix(Self.maxPhraseLength))
        guard !cleaned.isEmpty,
              !profile.phrases.contains(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame })
        else { return false }
        profile.phrases.append(cleaned)
        return true
    }

    func removePhrase(_ phrase: String) {
        profile.phrases.removeAll { $0 == phrase }
    }
}
