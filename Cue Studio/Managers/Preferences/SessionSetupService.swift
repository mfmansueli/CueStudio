//
//  SessionSetupService.swift
//  Cue Studio
//

import Foundation

/// The setup of the recording session that is open: the Creator Setup, the platform recommendation
/// the creator accepted and what they changed for this take (see `SessionSetup`). Lives as long as
/// the prompter. Camera, prompter, sheets, takes and the remote all read `camera` and `prompter`
/// from here instead of the stored preferences.
///
/// Writing through it keeps the rule that matters most: a recommendation or a change for one take
/// never rewrites the creator's defaults. Settings outside the Creator Setup (grid, countdown, font,
/// window size…) are still saved as the creator changes them, as they always were.
@MainActor
@Observable
final class SessionSetupService {
    private(set) var setup = SessionSetup()

    private let preferences: PreferencesService

    init(preferences: PreferencesService) {
        self.preferences = preferences
    }

    // MARK: - Reading

    /// How the creator usually records.
    var creatorSetup: CreatorSetup { preferences.creatorSetup }

    /// What this session records with.
    var current: CreatorSetup { setup.resolved(from: creatorSetup) }

    /// Camera settings for this session. Setting it records the Creator Setup fields that changed
    /// as changes for this take and saves the rest.
    var camera: CameraSettings {
        get { current.applied(to: preferences.camera) }
        set {
            var changed = current
            changed.update(from: newValue)
            record(changed)
            let stored = creatorSetup.applied(to: newValue)
            if stored != preferences.camera { preferences.camera = stored }
        }
    }

    /// Prompter settings for this session, with the same rule as `camera`.
    var prompter: PrompterSettings {
        get { current.applied(to: preferences.prompter) }
        set {
            var changed = current
            changed.update(from: newValue)
            record(changed)
            let stored = creatorSetup.applied(to: newValue)
            if stored != preferences.prompter { preferences.prompter = stored }
        }
    }

    // MARK: - Recommendation

    var recommendation: SetupRecommendation? { setup.recommendation }

    var choice: RecommendationChoice { setup.choice }

    /// Where the recommendation differs from the Creator Setup.
    var conflicts: [SetupConflict] { setup.conflicts(with: creatorSetup) }

    /// The recommendation card asks until the creator answers.
    var needsDecision: Bool { setup.needsDecision(with: creatorSetup) }

    /// Changed anything for this take.
    var hasChanges: Bool { !setup.overrides.isEmpty }

    func source(of field: SetupField) -> SetupSource {
        setup.source(of: field)
    }

    /// Where the frame and quality on screen come from.
    var captureSource: SetupSource { setup.captureSource }

    /// The creator's usual values for the fields the recommendation sets: "9:16 · 4K · 30 fps".
    var usualSummary: String {
        creatorSetup.summary(of: recommendation?.fields ?? [])
    }

    // MARK: - Actions

    func recommend(_ recommendation: SetupRecommendation?) {
        setup.recommend(recommendation)
    }

    func useRecommended() {
        setup.useRecommended()
    }

    func keepCreatorSetup() {
        setup.keepCreatorSetup()
    }

    func settleUndecided() {
        setup.settleUndecided()
    }

    func backToCreatorSetup() {
        setup.backToCreatorSetup()
    }

    private func record(_ changed: CreatorSetup) {
        let before = current
        guard changed != before else { return }
        setup.record(from: before, to: changed, creatorSetup: creatorSetup)
    }
}
