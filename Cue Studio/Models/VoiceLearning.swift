//
//  VoiceLearning.swift
//  Cue Studio
//

import Foundation

/// A change "Adjust" kept in the voice (the owner's item 11, 02/11/2026): which adjustment, what was too long, when, and the voice before and after,
/// so that "What Cue learned" can list it and taking it away puts back what it changed.
nonisolated struct VoiceLearning: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    /// `VoiceAdjustment.rawValue`.
    var adjustment: String
    /// `TooLongCause.rawValue`, for "Too long".
    var cause: String?
    var addedAt: Date = .now
    var before: Snapshot
    var after: Snapshot

    /// The part of the voice an adjustment can change.
    struct Snapshot: Codable, Hashable, Sendable {
        var sounds: [VoiceSound]
        var vocabulary: Vocabulary
        /// The styles older builds kept ("Too long" adds short sentences to them too).
        var styles: [VoiceStyle]
        var style: VoiceDelivery
        var phrases: [String]
        var reach: VoiceReach

        init(_ profile: CreatorProfile) {
            sounds = profile.sounds
            vocabulary = profile.vocabulary
            styles = profile.styles
            style = profile.style
            phrases = profile.phrases
            reach = profile.reach
        }
    }

    /// How many changes are kept; the oldest goes.
    static let limit = 12

    var kind: VoiceAdjustment? { VoiceAdjustment(rawValue: adjustment) }
    var tooLongCause: TooLongCause? { cause.flatMap(TooLongCause.init(rawValue:)) }

    /// What changed, in a line ("Sentences · Mixed → Short").
    var change: String { kind?.change(cause: tooLongCause) ?? "" }

    /// The profile with this change taken back: each value it changed goes back to what it was, unless the creator has changed that value since.
    func undone(in profile: CreatorProfile) -> CreatorProfile {
        var profile = profile
        revert(\.sounds, before.sounds, after.sounds, in: &profile)
        revert(\.vocabulary, before.vocabulary, after.vocabulary, in: &profile)
        revert(\.styles, before.styles, after.styles, in: &profile)
        revert(\.style.energy, before.style.energy, after.style.energy, in: &profile)
        revert(\.style.sentences, before.style.sentences, after.style.sentences, in: &profile)
        revert(\.style.words, before.style.words, after.style.words, in: &profile)
        revert(\.style.swearing, before.style.swearing, after.style.swearing, in: &profile)
        revert(\.style.oneIdea, before.style.oneIdea, after.style.oneIdea, in: &profile)
        revert(\.phrases, before.phrases, after.phrases, in: &profile)
        revert(\.reach.length, before.reach.length, after.reach.length, in: &profile)
        return profile
    }

    /// Whether the adjustment changed anything at all (one that finds nothing to change isn't listed).
    var changesSomething: Bool { before != after }

    private func revert<Value: Equatable>(
        _ path: WritableKeyPath<CreatorProfile, Value>, _ before: Value, _ after: Value, in profile: inout CreatorProfile
    ) {
        if before != after, profile[keyPath: path] == after { profile[keyPath: path] = before }
    }
}
