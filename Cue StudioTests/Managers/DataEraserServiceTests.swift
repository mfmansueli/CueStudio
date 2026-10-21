//
//  DataEraserServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Delete my Cue data")
struct DataEraserServiceTests {
    @Test func everythingTheCreatorMadeGoesAndTheExportCounterStays() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let script = TestData.script()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let take = TestData.take(scriptID: script.id)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.saveVoiceSetup(role: .entertainer, niches: [.food], vocabulary: .simple, sounds: [.casual])
        // What the creator imported and what Cue learned from their approvals is theirs to erase too.
        let imported = WritingAnalyzer.analyze(WritingSamples.maya.map { WritingPiece(text: $0) })
        profile.apply(WritingImportProposalBuilder.build(analysis: imported, reading: nil, profile: profile.profile))
        profile.recordApproval(of: "Okay, real talk. " + String(repeating: "Mornings are hard for everybody and that is fine. ", count: 6))
        #expect(!profile.profile.excerpts.isEmpty && profile.profile.fingerprint != nil && !profile.profile.approvedSamples.isEmpty)
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.customCues = ["laugh"]
        let quota = UsageQuotaService(counter: FakeExportCountStore(count: 3), defaults: defaults.defaults)
        let brands = BrandStore(repository: InMemoryBrandRepository())
        _ = brands.save(BrandBrief(name: "Acme", product: "Soap"))
        let sky = SkyMemory(defaults: defaults.defaults)
        _ = sky.addStar()
        let eraser = DataEraserService(
            library: library, takes: takes, drafts: FakeDraftStore(), logbook: LogbookService(defaults: defaults.defaults), brands: brands,
            sky: sky, profile: profile, preferences: preferences, defaults: defaults.defaults
        )

        eraser.eraseEverything()

        #expect(library.scripts.isEmpty)
        #expect(takes.takes.isEmpty)
        #expect(brands.brands.isEmpty)
        #expect(sky.points.isEmpty)
        #expect(profile.profile == CreatorProfile())
        #expect(profile.profile.excerpts.isEmpty && profile.profile.fingerprint == nil && profile.profile.approvedSamples.isEmpty)
        #expect(preferences.customCues.isEmpty)
        #expect(PreferencesService(defaults: defaults.defaults).customCues.isEmpty)
        // The 3 exports used are still used: deleting data can't hand back free exports.
        #expect(quota.exportsLeft(for: .free) == 2)
    }

    @Test func theVoiceTipsStartOverAndTheirOldHistoryIsNeverWrittenBack() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        let scheduler = VoiceQuestionScheduler(profile: profile, defaults: defaults.defaults)
        scheduler.registerAppOpen()
        scheduler.skipped(.openings)
        let eraser = DataEraserService(
            library: ScriptLibraryService(repository: FakeScriptRepository(scripts: [])), takes: TakeLibraryService(repository: FakeTakeRepository()),
            drafts: FakeDraftStore(), logbook: LogbookService(defaults: defaults.defaults), brands: BrandStore(repository: InMemoryBrandRepository()),
            sky: SkyMemory(defaults: defaults.defaults), profile: profile, preferences: PreferencesService(defaults: defaults.defaults),
            defaults: defaults.defaults, voiceQuestions: scheduler
        )

        eraser.eraseEverything()

        #expect(scheduler.state == VoiceQuestionState())
        // The scheduler's next save (any tip event) keeps only what happened after the erase.
        scheduler.skipped(.endings)
        let relaunched = VoiceQuestionScheduler(profile: profile, defaults: defaults.defaults)
        #expect(relaunched.state.skipped == [VoiceQuestion.endings.rawValue])
        #expect(relaunched.state.firstEligibleDays.isEmpty)
    }

    /// What is on disk goes too, not only what the screens show: a fresh read finds nothing, and nothing made from the creator's
    /// work is left behind (folders, the ideas written for them, the share queue, exported videos, a damaged library's copies).
    @Test func nothingTheCreatorMadeIsLeftOnDisk() throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let folder = URL.temporaryDirectory.appending(path: "erase-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let scriptFolder = folder.appending(path: "Library", directoryHint: .isDirectory)
        let takeFolder = folder.appending(path: "Takes", directoryHint: .isDirectory)
        let exportFolder = folder.appending(path: "Exports", directoryHint: .isDirectory)
        for directory in [scriptFolder, takeFolder, exportFolder] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let script = TestData.script(folder: "Ideas")
        try LocalScriptRepository(directory: scriptFolder).save(ScriptLibrarySnapshot(scripts: [script], folders: ["Ideas"]))
        try Data("old library".utf8).write(to: scriptFolder.appending(path: "scripts-kept-2026.json"))
        try Data("old takes".utf8).write(to: takeFolder.appending(path: "takes-kept-2026.json"))
        let library = ScriptLibraryService(repository: LocalScriptRepository(directory: scriptFolder))
        library.load()
        let take = TestData.take(scriptID: script.id)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let quota = UsageQuotaService(counter: FakeExportCountStore(count: 1), defaults: defaults.defaults)
        let ledger = ExportLedgerService(store: FakeExportLedgerStore(), quota: quota, directory: exportFolder)
        let exported = exportFolder.appending(path: "export.mp4")
        try Data([1]).write(to: exported)
        _ = ledger.begin(takeID: take.id, fingerprint: "f", file: exported)
        let shareQueue = ShareQueueService(defaults: defaults.defaults)
        _ = shareQueue.begin(takeID: take.id, operationID: UUID(), title: script.title, networks: [.tiktok])
        defaults.defaults.set(Data("ideas".utf8), forKey: DefaultsKey.ideaSuggestions)
        defaults.defaults.set(Data("cover".utf8), forKey: DefaultsKey.myCoverStudioStyle)
        let profile = CreatorProfileService(defaults: defaults.defaults)
        let ideas = IdeaSuggestionService(writer: FakeScriptWriter(), profile: profile, interfaceLanguage: { .english }, defaults: defaults.defaults)
        let eraser = DataEraserService(
            library: library, takes: takes, drafts: FakeDraftStore(), logbook: LogbookService(defaults: defaults.defaults),
            brands: BrandStore(repository: InMemoryBrandRepository()), sky: SkyMemory(defaults: defaults.defaults), profile: profile,
            preferences: PreferencesService(defaults: defaults.defaults), defaults: defaults.defaults, ledger: ledger, shareQueue: shareQueue,
            ideas: ideas
        )

        eraser.eraseEverything()

        let reread = try LocalScriptRepository(directory: scriptFolder).load()
        #expect(reread.scripts.isEmpty)
        #expect(reread.folders.isEmpty, "the folders go with the scripts")
        #expect(library.folders.isEmpty)
        let left = try FileManager.default.contentsOfDirectory(atPath: scriptFolder.path(percentEncoded: false))
        #expect(left == ["scripts.json"], "a damaged library's copy holds scripts too")
        #expect(!FileManager.default.fileExists(atPath: exported.path(percentEncoded: false)), "the exported video waiting to be shared")
        #expect(shareQueue.queues.isEmpty)
        #expect(ShareQueueService(defaults: defaults.defaults).queues.isEmpty)
        #expect(defaults.defaults.object(forKey: DefaultsKey.ideaSuggestions) == nil)
        #expect(defaults.defaults.object(forKey: DefaultsKey.myCoverStudioStyle) == nil)
        // The ledger keeps its ids so deleting data can't hand back free exports.
        #expect(quota.exportsLeft(for: .free) == 4)
    }
}
