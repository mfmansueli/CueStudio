//
//  WritingImportProposalBuilder.swift
//  Cue Studio
//

import Foundation

/// Turns what was found (`WritingAnalysis`, and what the model said of the style) into what the creator reviews, against what they already
/// answered: what is the same is left out, a new answer starts on, and one that would replace an answer of theirs starts off. Lists (phrases,
/// openings, endings, topics) add to what they hold, up to the limit, and never take anything away.
nonisolated enum WritingImportProposalBuilder {
    static func build(analysis: WritingAnalysis, reading: StyleReading?, profile: CreatorProfile) -> WritingImportProposal {
        var proposal = WritingImportProposal(
            excerpts: analysis.excerpts, fingerprint: analysis.fingerprint, pieceCount: analysis.pieceCount, wordCount: analysis.wordCount,
            language: analysis.language, isMixedLanguage: analysis.isMixedLanguage, blockedPieces: analysis.blockedPieces,
            usedAppleIntelligence: reading != nil
        )
        func single(_ value: WritingFinding.Value, held: Bool, same: Bool, support: WritingFinding.Support? = nil) {
            guard !same else { return }
            proposal.findings.append(WritingFinding(value: value, isOn: !held, replaces: held, support: support))
        }
        func additions(_ value: WritingFinding.Value?, support: WritingFinding.Support? = nil) {
            guard let value else { return }
            proposal.findings.append(WritingFinding(value: value, isOn: true, replaces: false, support: support))
        }

        // What Apple Intelligence read.
        if let reading {
            let tones = unique(reading.tones.compactMap(VoiceSound.init(rawValue:))).prefix(VoiceLimits.tones).map { $0 }
            if !tones.isEmpty {
                single(.tones(tones), held: profile.hasAnswered(.tone), same: profile.hasAnswered(.tone) && Set(profile.sounds) == Set(tones))
            }
            additions(topics(reading.topics, profile: profile))
            if let group = AudienceGroup(rawValue: reading.audience) {
                let held = profile.isChosen(.audience) && (profile.audienceGroup != nil || profile.audienceNote != nil)
                single(.audience(group), held: held, same: profile.audienceGroup == group)
            }
            if let humor = HumorLevel(rawValue: reading.humor) {
                single(.humor(humor), held: profile.reach.humor != nil, same: profile.reach.humor == humor)
            }
        }

        // What was measured.
        if let value = analysis.sentences { single(.sentences(value), held: profile.style.sentences != nil, same: profile.style.sentences == value) }
        if let value = analysis.words { single(.words(value), held: profile.style.words != nil, same: profile.style.words == value) }
        if let value = analysis.energy { single(.energy(value), held: profile.style.energy != nil, same: profile.style.energy == value) }
        if let value = analysis.swearing { single(.swearing(value), held: profile.style.swearing != nil, same: profile.style.swearing == value) }
        if let value = analysis.speaksAs { single(.speaksAs(value), held: profile.speaksAs != nil, same: profile.speaksAs == value) }
        if let value = analysis.length { single(.length(value), held: profile.reach.length != nil, same: profile.reach.length == value) }

        // What came back often enough to be a habit.
        let held = Set(profile.phrases.map(VoiceTextValidator.key))
        let phrases = analysis.phrases.filter { !held.contains(VoiceTextValidator.key($0)) }.prefix(max(0, VoiceLimits.phrases - profile.phrases.count))
        if !phrases.isEmpty { additions(.phrases(Array(phrases))) }
        additions(
            choices(analysis.openings, held: profile.openings, limit: VoiceLimits.openings, make: WritingFinding.Value.openings),
            support: support(for: analysis.openings, counts: analysis.openingCounts, of: analysis.pieceCount)
        )
        additions(
            choices(analysis.endings, held: profile.endings, limit: VoiceLimits.endings, make: WritingFinding.Value.endings),
            support: support(for: analysis.endings, counts: analysis.endingCounts, of: analysis.pieceCount)
        )
        return proposal
    }

    // MARK: - Helpers

    private static func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        return values.filter { seen.insert($0).inserted }
    }

    /// The topics the model named that the creator doesn't hold, as many as fit.
    private static func topics(_ ids: [String], profile: CreatorProfile) -> WritingFinding.Value? {
        let heldIDs = Set(profile.topics.map(\.id))
        let room = max(0, VoiceLimits.topics - profile.topicCount)
        let found = unique(ids).filter { CreatorProfileService.topicRef(for: $0) != nil && !heldIDs.contains($0) }.prefix(room)
        return found.isEmpty ? nil : .topics(Array(found))
    }

    /// The ids of an opening or ending the creator doesn't hold yet, as many as fit.
    private static func choices(
        _ ids: [String], held: [String], limit: Int, make: ([String]) -> WritingFinding.Value
    ) -> WritingFinding.Value? {
        let new = ids.filter { id in !held.contains { VoiceChoiceCatalog.key(matching: $0, among: [id]) != nil } }.prefix(max(0, limit - held.count))
        return new.isEmpty ? nil : make(Array(new))
    }

    private static func support(for ids: [String], counts: [String: Int], of pieces: Int) -> WritingFinding.Support? {
        guard let first = ids.first, let found = counts[first] else { return nil }
        return WritingFinding.Support(found: found, of: pieces)
    }
}
