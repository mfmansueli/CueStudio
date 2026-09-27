//
//  CreatorProfileServiceTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@MainActor
@Suite("CreatorProfileService")
struct CreatorProfileServiceTests {
    @Test func phrasesAreCleanedAndUnique() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        #expect(service.addPhrase("  “Hey fam”  "))
        #expect(!service.addPhrase("hey FAM"))
        #expect(!service.addPhrase("   "))
        #expect(service.profile.phrases == ["Hey fam"])
        service.removePhrase("Hey fam")
        #expect(service.profile.phrases.isEmpty)
    }

    @Test func nichesToggle() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.toggleNiche(.tech)
        #expect(service.profile.niches == [.tech])
        service.toggleNiche(.tech)
        #expect(service.profile.niches.isEmpty)
    }

    @Test func profilePersists() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.profile.name = "Maya Reyes"
        service.profile.defaultPlatform = .youtube
        let reloaded = CreatorProfileService(defaults: store.defaults)
        #expect(reloaded.profile.name == "Maya Reyes")
        #expect(reloaded.profile.defaultPlatform == .youtube)
        #expect(reloaded.profile.initials == "MR")
    }
}
