//
//  CreatorProfileService+WritingImport.swift
//  Cue Studio
//

import Foundation

/// What "Import my writing" leaves in the profile once the creator accepts: the findings they left on, the excerpts and the measures. One write, so
/// the voice never holds half of an import.
extension CreatorProfileService {
    /// Saves the accepted part of `proposal`; returns how many findings went in.
    @discardableResult
    func apply(_ proposal: WritingImportProposal) -> Int {
        var updated = profile
        var applied = 0
        for finding in proposal.findings where finding.isOn {
            apply(finding.value, to: &updated)
            applied += 1
        }
        if !proposal.excerpts.isEmpty { updated.excerpts = Self.merged(proposal.excerpts, into: updated.excerpts) }
        if let fingerprint = proposal.fingerprint, fingerprint.words >= (updated.fingerprint?.words ?? 0) { updated.fingerprint = fingerprint }
        profile = updated
        return applied
    }

    /// Forgets what was imported (the excerpts and the measures); what the creator answered from it stays theirs.
    func clearImportedWriting() {
        var updated = profile
        updated.excerpts = []
        updated.fingerprint = nil
        profile = updated
    }

    /// Takes one excerpt out of what was imported (the creator reads them and decides); the measures stay.
    func removeExcerpt(_ id: UUID) {
        profile.excerpts.removeAll { $0.id == id }
    }

    /// The new excerpts first, then the ones already kept, without repeats, up to the library's size.
    static func merged(_ new: [VoiceExcerpt], into kept: [VoiceExcerpt]) -> [VoiceExcerpt] {
        var seen = Set<String>()
        return (new + kept).filter { seen.insert(VoiceTextValidator.key($0.text)).inserted }.prefix(VoiceExcerpt.limit).map { $0 }
    }

    private func apply(_ value: WritingFinding.Value, to updated: inout CreatorProfile) {
        switch value {
        case .tones(let tones):
            updated.sounds = tones
            updated.confirm(.tone)
        case .topics(let ids):
            for id in ids {
                guard let topic = Self.topicRef(for: id) else { continue }
                _ = Self.toggle(topic, in: &updated)
            }
        case .audience(let group):
            updated.audienceGroup = group
            updated.audienceNote = nil
            updated.vocabulary = group.vocabulary
            updated.confirm(.audience)
        case .sentences(let sentences): updated.style.sentences = sentences
        case .words(let words): updated.style.words = words
        case .energy(let energy): updated.style.energy = energy
        case .humor(let humor): updated.reach.humor = humor
        case .swearing(let swearing): updated.style.swearing = swearing
        case .speaksAs(let speaksAs): updated.speaksAs = speaksAs
        case .length(let length): updated.reach.length = length
        case .phrases, .openings, .endings: applyList(value, to: &updated)
        }
    }

    /// The answers that are lists add to what the creator holds, up to the limit.
    private func applyList(_ value: WritingFinding.Value, to updated: inout CreatorProfile) {
        switch value {
        case .phrases(let phrases):
            for phrase in phrases where updated.phrases.count < VoiceLimits.phrases {
                let key = VoiceTextValidator.key(phrase)
                if !updated.phrases.contains(where: { VoiceTextValidator.key($0) == key }) { updated.phrases.append(phrase) }
            }
        case .openings(let ids):
            for id in ids where updated.openings.count < VoiceLimits.openings { updated.openings.append(VoiceChoiceCatalog.openingLabel(id)) }
        case .endings(let ids):
            for id in ids where updated.endings.count < VoiceLimits.endings { updated.endings.append(VoiceChoiceCatalog.endingLabel(id)) }
        default:
            break
        }
    }
}
