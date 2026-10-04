//
//  TopicTaggingService.swift
//  Cue Studio
//

import Foundation
import SwiftUI

/// Tags each new script with one of the creator's topics, on this iPhone (Settings › Personalize › Tag new scripts
/// automatically). With one topic there is nothing to choose; with more, the on-device model reads the script and
/// picks one, or none when none fits. The creator can change any tag, and a tag they set is never touched.
@MainActor
@Observable
final class TopicTaggingService {
    /// A script this short has not said what it is about yet.
    static let minimumWords = 12

    @ObservationIgnored private let library: ScriptLibraryService
    @ObservationIgnored private let profile: CreatorProfileService
    @ObservationIgnored private let personalization: PersonalizationService
    @ObservationIgnored private let writer: ScriptWriting
    @ObservationIgnored private var inFlight: Set<UUID> = []

    init(library: ScriptLibraryService, profile: CreatorProfileService, personalization: PersonalizationService, writer: ScriptWriting) {
        self.library = library
        self.profile = profile
        self.personalization = personalization
        self.writer = writer
    }

    /// The creator's topics, in the order their colors are given.
    var topics: [OnboardingTopic] {
        let creator = profile.profile
        return Array((creator.niches.map(OnboardingTopic.niche) + creator.customTopics.map(OnboardingTopic.custom)).prefix(OnboardingTopic.limit))
    }

    /// Tags the scripts that have no topic yet. Safe to call whenever the library changes.
    func tagUntagged() async {
        guard personalization.autoTagsTopics, !topics.isEmpty else { return }
        let candidates = library.scripts.filter {
            $0.topic == nil && ReadTime.wordCount(in: $0.text) >= Self.minimumWords && !inFlight.contains($0.id)
        }
        for script in candidates.prefix(5) {
            inFlight.insert(script.id)
            let choice = await topic(for: script)
            inFlight.remove(script.id)
            // The creator may have set one while the model was reading.
            guard library.script(id: script.id)?.topic == nil else { continue }
            library.setTopic(choice?.id ?? "", of: script.id)
        }
    }

    private func topic(for script: Script) async -> OnboardingTopic? {
        await topic(forText: script.text)
    }

    /// The topic some words are about: the only one there is, or the one the on-device model picks.
    func topic(forText text: String) async -> OnboardingTopic? {
        guard personalization.autoTagsTopics else { return nil }
        let known = topics
        if known.count == 1 { return known[0] }
        guard !known.isEmpty, let name = await writer.pickTopic(for: text, among: known.map(\.label)) else { return nil }
        return known.first { $0.label.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// The color of the world a script's topic is, nil when it has none.
    func color(for script: Script) -> Color? {
        guard let id = script.topic, !id.isEmpty, let index = topics.firstIndex(where: { $0.id == id }) else { return nil }
        return OnboardingTopic.color(at: index)
    }
}
