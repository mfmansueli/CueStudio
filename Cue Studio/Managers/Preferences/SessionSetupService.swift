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
/// never rewrites the creator's camera defaults. Prompter settings stay in the session while it is open, and what the
/// creator left is remembered when Aa closes and when the prompter does (`rememberReadingLayout`). Other camera
/// options (grid, countdown…) are still saved as before. Defaults are captured when the session
/// opens, so editing Creator Setup cannot change an open recording.
@MainActor
@Observable
final class SessionSetupService {
    private(set) var setup = SessionSetup()

    /// The Selfie preview fills the screen and the sides that don't fit run past its edges (the recording keeps the whole
    /// frame). Never saved: every time the camera opens it shows the whole frame, so the creator sees all of the image the
    /// social networks will show, and the choice lives only as long as the prompter.
    var fillsScreen = false

    private let preferences: PreferencesService
    let creatorSetup: CreatorSetup
    private let initialPrompter: PrompterSettings
    private var sessionPrompter: PrompterSettings

    init(preferences: PreferencesService) {
        self.preferences = preferences
        creatorSetup = preferences.creatorSetup
        initialPrompter = preferences.prompter
        sessionPrompter = preferences.prompter
    }

    // MARK: - Reading

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
            let stored = preferences.creatorSetup.applied(to: newValue)
            if stored != preferences.camera { preferences.camera = stored }
        }
    }

    /// Reading preferences start from the saved defaults. Every edit here is local to this
    /// session; Creator Setup is the place that changes the defaults.
    var prompter: PrompterSettings {
        get { current.applied(to: sessionPrompter) }
        set {
            var changed = current
            changed.update(from: newValue)
            record(changed)
            sessionPrompter = newValue
        }
    }

    // MARK: - Safe zone

    /// "Use Recommended" moved the safe zone off the creator's Custom one onto the network's, for this session only: their Custom
    /// margins stay saved for the next one.
    private(set) var followsNetworkZone = false

    /// The safe zone the creator picked in Aa › Window: Custom, or nil to follow the recording's network. Choosing again (Custom or
    /// the network) ends what "Use Recommended" set.
    var safeZonePick: SafeZoneChoice? {
        get { followsNetworkZone ? nil : SafeZoneChoice.pick(fromKey: prompter.safeZoneKey) }
        set {
            followsNetworkZone = false
            prompter.safeZoneKey = newValue == .custom ? SafeZoneChoice.custom.key : nil
        }
    }

    // MARK: - Remembering

    /// Everything the creator set in the prompter (Aa, the box, the line, the size, the speed, the mode…) becomes what the next session
    /// opens with, as a change in Settings would: the prompter comes back as it was left, in Selfie and in Studio. The camera, a
    /// recommendation used or any other change for one take stays with its session. `includingScrollMode` false keeps the saved mode
    /// (one the practice, or a session that can't follow the voice, set by itself).
    func rememberReadingLayout(includingScrollMode: Bool = true) {
        var stored = prompter
        if !includingScrollMode { stored.scrollMode = preferences.prompter.scrollMode }
        if stored != preferences.prompter { preferences.prompter = stored }
    }

    // MARK: - Recommendation

    var recommendation: SetupRecommendation? { setup.recommendation }

    var choice: RecommendationChoice { setup.choice }

    /// What "Use Recommended" would change in the setup, against what is on screen (the safe zone is the prompter's to add).
    var changes: [SetupChange] { setup.changes(from: creatorSetup) }

    /// Changed anything for this take.
    var hasChanges: Bool {
        !setup.overrides.isEmpty || !setup.accepted.isEmpty || followsNetworkZone
            || creatorSetup.applied(to: sessionPrompter) != initialPrompter
    }

    func source(of field: SetupField) -> SetupSource {
        setup.source(of: field)
    }

    /// Where the frame and quality on screen come from.
    var captureSource: SetupSource { setup.captureSource }

    // MARK: - Actions

    func recommend(_ recommendation: SetupRecommendation?) {
        setup.recommend(recommendation)
    }

    /// "Use Recommended"; `includingSafeZone` when the card listed the safe zone (the creator's Custom one gives way to the network's).
    func useRecommended(includingSafeZone: Bool = false) {
        setup.useRecommended()
        if includingSafeZone { followsNetworkZone = true }
    }

    /// "Keep as is".
    func keepAsIs() {
        setup.keepAsIs()
    }

    func settleUndecided() {
        setup.settleUndecided()
    }

    func backToCreatorSetup() {
        setup.backToCreatorSetup()
        followsNetworkZone = false
        sessionPrompter = initialPrompter
    }

    private func record(_ changed: CreatorSetup) {
        let before = current
        guard changed != before else { return }
        setup.record(from: before, to: changed, creatorSetup: creatorSetup)
    }
}
