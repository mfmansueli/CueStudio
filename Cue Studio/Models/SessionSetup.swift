//
//  SessionSetup.swift
//  Cue Studio
//

import Foundation

/// The setup of one recording session, in layers, most important first:
///
/// 1. what the creator changed for this take (`overrides`);
/// 2. the platform recommendation, once the creator accepted it;
/// 3. the Creator Setup;
/// 4. the system's fallback, at capture time (another camera or mic when the one asked for isn't
///    there — see `CaptureEngine` and `MicrophoneFallback`).
///
/// A recommendation is never applied on its own: until the creator answers, the Creator Setup is
/// what records, and the question is on screen. Nothing here is saved; the Creator Setup only
/// changes in Settings › Creator Setup.
nonisolated struct SessionSetup: Hashable, Sendable {
    private(set) var recommendation: SetupRecommendation?
    private(set) var choice: RecommendationChoice = .undecided
    private(set) var overrides = SetupValues()

    init() {}

    // MARK: - Resolving

    /// What this session records with.
    func resolved(from creatorSetup: CreatorSetup) -> CreatorSetup {
        overrides.applied(to: base(from: creatorSetup))
    }

    /// Where the value of `field` comes from.
    func source(of field: SetupField) -> SetupSource {
        if overrides.fields.contains(field) { return .thisTake }
        if choice == .useRecommended, let recommendation, recommendation.fields.contains(field) {
            return .recommended(recommendation.platform)
        }
        return .creatorSetup
    }

    /// Where the frame and quality on the recording screen come from: "Your setup", "TikTok setup"
    /// or "This take".
    var captureSource: SetupSource {
        let sources = [SetupField.format, .quality, .frameRate].map(source(of:))
        if sources.contains(.thisTake) { return .thisTake }
        return sources.first { $0 != .creatorSetup } ?? .creatorSetup
    }

    func conflicts(with creatorSetup: CreatorSetup) -> [SetupConflict] {
        recommendation?.conflicts(with: creatorSetup) ?? []
    }

    /// The recommendation differs from the Creator Setup and the creator hasn't chosen yet.
    func needsDecision(with creatorSetup: CreatorSetup) -> Bool {
        choice == .undecided && !conflicts(with: creatorSetup).isEmpty
    }

    // MARK: - Changes

    /// New content (a script, or another platform for it). A new recommendation asks again.
    mutating func recommend(_ recommendation: SetupRecommendation?) {
        guard recommendation != self.recommendation else { return }
        self.recommendation = recommendation
        choice = .undecided
    }

    /// "Use Recommended": for this session only. Its fields win over earlier changes, since the
    /// creator just asked for them.
    mutating func useRecommended() {
        guard let recommendation else { return }
        choice = .useRecommended
        overrides.clear(recommendation.fields)
    }

    /// "Keep My Setup".
    mutating func keepCreatorSetup() {
        choice = .keepCreatorSetup
        if let recommendation { overrides.clear(recommendation.fields) }
    }

    /// Recording without answering keeps the Creator Setup, which is what was on screen.
    mutating func settleUndecided() {
        guard choice == .undecided, recommendation != nil else { return }
        choice = .keepCreatorSetup
    }

    /// A change made while recording (flip the camera, drag the line, another mic…). Only what
    /// differs from the layers underneath is kept.
    mutating func record(from old: CreatorSetup, to new: CreatorSetup, creatorSetup: CreatorSetup) {
        overrides.record(from: old, to: new)
        overrides.removeMatching(base(from: creatorSetup))
    }

    /// "Back to my setup": drops this session's changes and the recommendation.
    mutating func backToCreatorSetup() {
        overrides = SetupValues()
        choice = recommendation == nil ? .undecided : .keepCreatorSetup
    }

    private func base(from creatorSetup: CreatorSetup) -> CreatorSetup {
        guard choice == .useRecommended, let recommendation else { return creatorSetup }
        return recommendation.applied(to: creatorSetup)
    }
}
