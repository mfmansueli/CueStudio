//
//  DataEraserService.swift
//  Cue Studio
//

import Foundation

/// "Delete my Cue data" (Settings › Privacy & AI data, 04 · F8): everything the creator made leaves this iPhone for good —
/// scripts, takes and their videos and edits, the Logbook, saved brands, "your stars", My Cue Voice and the recording
/// setup. Not touched: the purchase (it belongs to the Apple ID), the free-export counter (kept in the Keychain so
/// deleting data can't hand back free exports), the language and what Photos already holds. Irreversible, so the screen
/// asks first.
@MainActor
@Observable
final class DataEraserService {
    @ObservationIgnored private let library: ScriptLibraryService
    @ObservationIgnored private let takes: TakeLibraryService
    @ObservationIgnored private let drafts: QuickEditDraftStoring
    @ObservationIgnored private let logbook: LogbookService
    @ObservationIgnored private let brands: BrandStore
    @ObservationIgnored private let sky: SkyMemory
    @ObservationIgnored private let profile: CreatorProfileService
    @ObservationIgnored private let preferences: PreferencesService
    @ObservationIgnored private let defaults: UserDefaults

    init(
        library: ScriptLibraryService, takes: TakeLibraryService, drafts: QuickEditDraftStoring, logbook: LogbookService,
        brands: BrandStore, sky: SkyMemory, profile: CreatorProfileService, preferences: PreferencesService, defaults: UserDefaults = .standard
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
        for key in [
            DefaultsKey.voiceNudgeSnoozes, DefaultsKey.myTextStyle, DefaultsKey.myCoverStyle, DefaultsKey.scriptEditorTextSize,
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
