//
//  SessionSetup.swift
//  Cue Studio
//

import Foundation

/// The setup of one recording session, in layers, most important first:
///
/// 1. what the creator changed for this take (`overrides`);
/// 2. the values of the platform recommendations the creator used ("Use Recommended", `accepted`);
/// 3. the Creator Setup;
/// 4. the system's fallback, at capture time (another camera or mic when the one asked for isn't
///    there — see `CaptureEngine` and `MicrophoneFallback`).
///
/// A recommendation is never applied on its own: until the creator answers, what is on screen is what records, and the question
/// lists what would change against it (`changes`). Asking again for another network never changes the screen either: what an earlier
/// "Use Recommended" set stays until the creator answers. Nothing here is saved; the Creator Setup only changes in Settings.
nonisolated struct SessionSetup: Hashable, Sendable {
    private(set) var recommendation: SetupRecommendation?
    private(set) var choice: RecommendationChoice = .undecided
    private(set) var overrides = SetupValues()
    /// What the recommendations the creator used set, under their own changes.
    private(set) var accepted = SetupValues()
    /// The network of the last recommendation used, for "Shorts setup".
    private(set) var acceptedPlatform: Platform?

    init() {}

    // MARK: - Resolving

    /// What this session records with.
    func resolved(from creatorSetup: CreatorSetup) -> CreatorSetup {
        overrides.applied(to: base(from: creatorSetup))
    }

    /// Where the value of `field` comes from.
    func source(of field: SetupField) -> SetupSource {
        if overrides.fields.contains(field) { return .thisTake }
        if let acceptedPlatform, accepted.fields.contains(field) { return .recommended(acceptedPlatform) }
        return .creatorSetup
    }

    /// Where the frame and quality on the recording screen come from: "Your setup", "TikTok setup"
    /// or "This take".
    var captureSource: SetupSource {
        let sources = [SetupField.format, .quality, .frameRate].map(source(of:))
        if sources.contains(.thisTake) { return .thisTake }
        return sources.first { $0 != .creatorSetup } ?? .creatorSetup
    }

    /// What "Use Recommended" would change against what is on screen, the creator's own choices for this take marked.
    func changes(from creatorSetup: CreatorSetup) -> [SetupChange] {
        recommendation?.changes(from: resolved(from: creatorSetup), manual: overrides.fields) ?? []
    }

    // MARK: - Changes

    /// New content (a script, or another network for it). A new recommendation asks again.
    mutating func recommend(_ recommendation: SetupRecommendation?) {
        guard recommendation != self.recommendation else { return }
        self.recommendation = recommendation
        choice = .undecided
    }

    /// "Use Recommended": for this session only, exactly what the card lists. Its fields win over earlier changes, since the creator
    /// just asked for them.
    mutating func useRecommended() {
        guard let recommendation else { return }
        choice = .useRecommended
        accepted = recommendation.values.applied(over: accepted)
        acceptedPlatform = recommendation.platform
        overrides.clear(recommendation.fields)
    }

    /// "Keep as is": nothing on screen changes.
    mutating func keepAsIs() {
        choice = .keepAsIs
    }

    /// Recording without answering keeps what was on screen.
    mutating func settleUndecided() {
        guard choice == .undecided, recommendation != nil else { return }
        choice = .keepAsIs
    }

    /// A change made while recording (flip the camera, drag the line, another mic…). Only what
    /// differs from the layers underneath is kept.
    mutating func record(from old: CreatorSetup, to new: CreatorSetup, creatorSetup: CreatorSetup) {
        overrides.record(from: old, to: new)
        overrides.removeMatching(base(from: creatorSetup))
    }

    /// "Back to my setup": drops this session's changes and the recommendations used.
    mutating func backToCreatorSetup() {
        overrides = SetupValues()
        accepted = SetupValues()
        acceptedPlatform = nil
        choice = recommendation == nil ? .undecided : .keepAsIs
    }

    private func base(from creatorSetup: CreatorSetup) -> CreatorSetup {
        accepted.applied(to: creatorSetup)
    }
}
