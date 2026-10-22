//
//  DataEraserService.swift
//  Cue Studio
//

import Foundation

/// "Delete my Cue data" (Settings › Privacy & AI data, 04 · F8): everything the creator made leaves this iPhone for good —
/// scripts and folders, takes and their videos and edits, exported videos waiting to be shared and the share queue, the
/// Logbook, saved brands, "your stars", My Cue Voice, the ideas Cue wrote and the taste it learned, my text and cover styles,
/// the recording setup, the first voyage's marks, Cue's drafts waiting for a take, the copies of a damaged library, and the
/// reminders, routine and notifications waiting.
/// Not touched: the purchase (it belongs to the Apple ID), the free-export counter and the exports' ledger (ids only: kept so
/// deleting data can't hand back free exports), the count of videos shared (the universe's planets), the language and what
/// Photos already holds. Irreversible, so the screen asks first.
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
    @ObservationIgnored private let profile: CreatorProfileService
    @ObservationIgnored private let preferences: PreferencesService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notifications: NotificationService?
    @ObservationIgnored private let voyage: FirstVoyageService?
    @ObservationIgnored private let draftLearning: DraftLearningService?
    @ObservationIgnored private let voiceQuestions: VoiceQuestionScheduler?
    @ObservationIgnored private let ledger: ExportLedgerService?
    @ObservationIgnored private let shareQueue: ShareQueueService?
    @ObservationIgnored private let ideas: IdeaSuggestionService?
    /// The editor's media folder and the camera's leftover recordings, whole. Tests point it at folders of their own: these
    /// are the app's, shared by every test running at the same time.
    @ObservationIgnored private let eraseLooseFiles: () -> Void

    init(
        library: ScriptLibraryService, takes: TakeLibraryService, drafts: QuickEditDraftStoring, logbook: LogbookService,
        brands: BrandStore, profile: CreatorProfileService, preferences: PreferencesService, defaults: UserDefaults = .standard,
        notifications: NotificationService? = nil, voyage: FirstVoyageService? = nil, draftLearning: DraftLearningService? = nil,
        voiceQuestions: VoiceQuestionScheduler? = nil, ledger: ExportLedgerService? = nil, shareQueue: ShareQueueService? = nil,
        ideas: IdeaSuggestionService? = nil,
        eraseLooseFiles: @escaping () -> Void = {
            EditMediaFiles.removeAll()
            TakeRecovery.removeLeftovers()
        }
    ) {
        self.library = library
        self.takes = takes
        self.drafts = drafts
        self.logbook = logbook
        self.brands = brands
        self.profile = profile
        self.preferences = preferences
        self.defaults = defaults
        self.notifications = notifications
        self.voyage = voyage
        self.draftLearning = draftLearning
        self.voiceQuestions = voiceQuestions
        self.ledger = ledger
        self.shareQueue = shareQueue
        self.ideas = ideas
        self.eraseLooseFiles = eraseLooseFiles
    }

    func eraseEverything() {
        for take in takes.takes {
            drafts.discard(takeID: take.id)
            ledger?.releaseFiles(forTake: take.id)
            takes.delete(take.id)
        }
        // Then the folders whole: what no take names any more (a take deleted before, an import that failed) goes too. Only
        // here, where the creator asked for everything to go: nothing else sweeps "orphans" (DESIGN_PROJECT.md §37).
        takes.deleteEverything()
        drafts.discardAll()
        eraseLooseFiles()
        shareQueue?.discardAll()
        library.delete(Set(library.scripts.map(\.id)))
        library.deleteFoldersAndKeptCopies()
        ideas?.forgetEverything()
        for entry in logbook.entries { logbook.delete(entry.id) }
        for brand in brands.brands { brands.remove(brand.id) }
        profile.profile = CreatorProfile()
        preferences.resetCreatorSetup()
        preferences.customCues = []
        preferences.showsCuesOnPage = true
        for key in [
            DefaultsKey.voiceQuestionState, DefaultsKey.myTextStyle,
            // "Your stars", which earlier versions kept and nothing shows any more.
            DefaultsKey.skyMemory, DefaultsKey.skyMemoryAdded, DefaultsKey.myCoverStyle, DefaultsKey.myCoverStudioStyle,
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
