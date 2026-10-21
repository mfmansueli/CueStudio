//
//  DataEraserService.swift
//  Cue Studio
//

import Foundation

/// "Delete my Cue data" (Settings › Privacy & AI data, 04 · F8): everything the creator made leaves this iPhone for good —
/// scripts, takes and their videos and edits, the Logbook, saved brands, "your stars", My Cue Voice, the recording
/// setup, the first voyage's marks, Cue's drafts waiting for a take, and the reminders, routine and notifications waiting.
/// Not touched: the purchase (it belongs to the Apple ID), the free-export counter (kept in the Keychain so deleting data can't
/// hand back free exports), the language and what Photos already holds. Irreversible, so the screen asks first.
@MainActor
@Observable
final class DataEraserService {
    /// "Delete my Cue data" was tapped and the creator has not answered the confirmation yet.
    var isConfirming = false

    @ObservationIgnored private let library: ScriptLibraryService
    @ObservationIgnored private let takes: TakeLibraryService
    @ObservationIgnored private let drafts: QuickEditDraftStoring
    @ObservationIgnored private let logbook: LogbookService
    @ObservationIgnored private let brands: BrandStore
    @ObservationIgnored private let sky: SkyMemory
    @ObservationIgnored private let profile: CreatorProfileService
    @ObservationIgnored private let preferences: PreferencesService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notifications: NotificationService?
    @ObservationIgnored private let voyage: FirstVoyageService?
    @ObservationIgnored private let draftLearning: DraftLearningService?
    @ObservationIgnored private let voiceQuestions: VoiceQuestionScheduler?

    init(
        library: ScriptLibraryService, takes: TakeLibraryService, drafts: QuickEditDraftStoring, logbook: LogbookService,
        brands: BrandStore, sky: SkyMemory, profile: CreatorProfileService, preferences: PreferencesService, defaults: UserDefaults = .standard,
        notifications: NotificationService? = nil, voyage: FirstVoyageService? = nil, draftLearning: DraftLearningService? = nil,
        voiceQuestions: VoiceQuestionScheduler? = nil
    ) {
        self.library = library
        self.takes = takes
        self.drafts = drafts
        self.logbook = logbook
        self.brands = brands
        self.sky = sky
        self.profile = profile
        self.preferences = preferences
        self.defaults = defaults
        self.notifications = notifications
        self.voyage = voyage
        self.draftLearning = draftLearning
        self.voiceQuestions = voiceQuestions
    }

    func eraseEverything() {
        for take in takes.takes {
            drafts.discard(takeID: take.id)
            takes.delete(take.id)
        }
        library.delete(Set(library.scripts.map(\.id)))
        for entry in logbook.entries { logbook.delete(entry.id) }
        for brand in brands.brands { brands.remove(brand.id) }
        sky.removeAll()
        profile.profile = CreatorProfile()
        preferences.resetCreatorSetup()
        preferences.customCues = []
        preferences.showsCuesOnPage = true
        for key in [
            DefaultsKey.voiceQuestionState, DefaultsKey.myTextStyle, DefaultsKey.myCoverStyle,
        ] {
            defaults.removeObject(forKey: key)
        }
        // The tips' memory lives in the scheduler too: left there, its next save would write it back.
        voiceQuestions?.reset()
        // With nothing made, the first voyage starts over (a video shared before still counts: it stays off then).
        voyage?.reset()
        // Cue's drafts waiting for a take, so nothing is learned from scripts that are gone.
        draftLearning?.clear()
        // Reminders, the routine and the history go with the rest; pending and delivered notifications are taken back.
        if let notifications { Task { await notifications.eraseAll() } }
    }
}
