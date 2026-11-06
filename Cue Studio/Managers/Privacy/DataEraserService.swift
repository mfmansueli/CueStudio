//
//  DataEraserService.swift
//  Cue Studio
//

import Foundation

/// "Delete my Cue data" (Settings › Privacy & AI data, 04 · F8): everything the creator made leaves this iPhone for good —
/// scripts and folders, takes and their videos and edits, exported videos waiting to be shared and the share queue, the
/// Logbook, the idea waiting in the dock, saved brands, the media library, brand kits and imported fonts, "your stars", My Cue Voice, the ideas Cue wrote
/// and the taste it learned, my text and cover styles, the recording setup, the first voyage's marks, Cue's drafts waiting for
/// a take, the copies of a damaged library, and the reminders, routine and notifications waiting.
/// Not touched: the purchase (it belongs to the Apple ID), the free-export counter (kept so deleting data can't hand back free
/// exports; the ledger's records of the erased takes go with them, `ExportLedgerService.forget`), the count of videos shared (the
/// universe's planets), the language and what Photos already holds. Irreversible, so the screen asks first.
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
    @ObservationIgnored private let fonts: CustomFontStore?
    @ObservationIgnored private let fontPacks: FontPackStore?
    @ObservationIgnored private let mediaLibrary: MediaLibraryStore?
    @ObservationIgnored private let brandKits: BrandKitStore?
    /// The dock's idea and choices, kept on disk (`DockDraft`).
    @ObservationIgnored private let ideaDraft: IdeaDraftService?
    /// The editor's media folder and the camera's leftover recordings, whole. Tests point it at folders of their own: these
    /// are the app's, shared by every test running at the same time.
    @ObservationIgnored private let eraseLooseFiles: () -> Void

    init(
        library: ScriptLibraryService, takes: TakeLibraryService, drafts: QuickEditDraftStoring, logbook: LogbookService,
        brands: BrandStore, profile: CreatorProfileService, preferences: PreferencesService, defaults: UserDefaults = .standard,
        notifications: NotificationService? = nil, voyage: FirstVoyageService? = nil, draftLearning: DraftLearningService? = nil,
        voiceQuestions: VoiceQuestionScheduler? = nil, ledger: ExportLedgerService? = nil, shareQueue: ShareQueueService? = nil,
        ideas: IdeaSuggestionService? = nil, fonts: CustomFontStore? = nil, fontPacks: FontPackStore? = nil, mediaLibrary: MediaLibraryStore? = nil,
        brandKits: BrandKitStore? = nil, ideaDraft: IdeaDraftService? = nil,
        eraseLooseFiles: @escaping () -> Void = {
            EditMediaFiles.removeAll()
            TakeRecovery.removeLeftovers()
            DataEraserService.removeTemporaryFiles(in: .temporaryDirectory)
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
        self.fonts = fonts
        self.fontPacks = fontPacks
        self.mediaLibrary = mediaLibrary
        self.brandKits = brandKits
        self.ideaDraft = ideaDraft
        self.eraseLooseFiles = eraseLooseFiles
    }

    /// Everything Cue left in `folder` under its own prefix: exported videos (of takes deleted before too), covers, sounds being made.
    nonisolated static func removeTemporaryFiles(in folder: URL) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        for name in names where name.hasPrefix("Cue-") {
            try? FileManager.default.removeItem(at: folder.appending(path: name))
        }
    }

    func eraseEverything() {
        for take in takes.takes {
            drafts.forget(takeID: take.id)
            ledger?.forget(takeID: take.id)
            takes.delete(take.id)
        }
        // Then the folders whole: what no take names any more (a take deleted before, an import that failed) goes too, now, without the
        // week `TakeOrphanSweep` waits for.
        takes.deleteEverything()
        drafts.discardAll()
        eraseLooseFiles()
        // The media library, the brand kits, the imported fonts and the downloaded ones (unregistered first).
        mediaLibrary?.eraseAll()
        brandKits?.eraseAll()
        fonts?.eraseAll()
        fontPacks?.eraseAll()
        shareQueue?.discardAll()
        library.delete(Set(library.scripts.map(\.id)))
        library.deleteFoldersAndKeptCopies()
        ideas?.forgetEverything()
        logbook.eraseAll()
        // The idea waiting in the dock, with its choices (in memory, or the next change would write it back).
        ideaDraft?.clear()
        for brand in brands.brands { brands.remove(brand.id) }
        profile.profile = CreatorProfile()
        preferences.resetCreatorSetup()
        preferences.customCues = []
        preferences.showsCuesOnPage = true
        for key in [
            DefaultsKey.voiceQuestionState, DefaultsKey.myTextStyle, DefaultsKey.catchphraseTurn,
            // "Your stars", which earlier versions kept and nothing shows any more.
            DefaultsKey.skyMemory, DefaultsKey.skyMemoryAdded, DefaultsKey.myCoverStyle, DefaultsKey.myCoverStudioStyle,
            // Every saved style, and the single caption style saved before them.
            DefaultsKey.myCaptionStyle, DefaultsKey.captionStyleLibrary, DefaultsKey.textStyleLibrary, DefaultsKey.coverStyleLibrary,
            DefaultsKey.captionCatalogFilter, DefaultsKey.dockDraft,
            // The takes' and the edits' folders went whole: nothing is left to sweep.
            DefaultsKey.takeDeletionsPending, DefaultsKey.takeOrphanSightings, DefaultsKey.editMediaDeletionsPending,
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
