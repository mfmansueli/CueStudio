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
}
