//
//  RememberedLookStoreTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The look Copy look took, kept per take in UserDefaults (`EditorPreferencesStore`), so it comes back without a draft.
@MainActor
struct RememberedLookStoreTests {
    private func makeStore() throws -> (EditorPreferencesStore, UserDefaults) {
        let defaults = try #require(UserDefaults(suiteName: "remembered-look-\(UUID().uuidString)"))
        return (EditorPreferencesStore(defaults: defaults), defaults)
    }

    private func look(exposure: Double) -> RememberedLook {
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        var segment = edit.timeline.segments[0]
        var own = ClipLook()
        own.exposure = exposure
        segment.look = own
        edit.timeline.replaceSegment(segment)
        return RememberedLook(
            copiedLook: CopiedClipLook(of: segment, in: edit),
            pasteLookChoice: PasteLookChoice(parts: [.adjust, .filter], everyClip: true)
        )
    }

    @Test func aTakesLookComesBackAndAnEmptyOneIsForgotten() throws {
        let (store, _) = try makeStore()
        let take = UUID(), other = UUID()
        store.setRememberedLook(look(exposure: 20), forTake: take)
        store.setRememberedLook(look(exposure: -10), forTake: other)
        #expect(store.rememberedLook(forTake: take) == look(exposure: 20))
        #expect(store.rememberedLook(forTake: other) == look(exposure: -10))

        store.setRememberedLook(look(exposure: 40), forTake: take)
        #expect(store.rememberedLook(forTake: take) == look(exposure: 40), "A newer copy takes the older one's place")

        store.setRememberedLook(RememberedLook(copiedLook: nil, pasteLookChoice: nil), forTake: take)
        #expect(store.rememberedLook(forTake: take) == nil)
        #expect(store.rememberedLook(forTake: other) == look(exposure: -10))
    }

    @Test func onlyTheTakesEditedLastAreKept() throws {
        let (store, _) = try makeStore()
        let takes = (0...EditorPreferencesStore.keptTimelineLanes).map { _ in UUID() }
        for take in takes { store.setRememberedLook(look(exposure: 10), forTake: take) }
        #expect(store.rememberedLook(forTake: takes[0]) == nil, "The oldest went")
        #expect(store.rememberedLook(forTake: takes[1]) != nil)
        #expect(store.rememberedLook(forTake: takes.last!) != nil)
    }

    @Test func aListItCantReadIsEmptyAndWrittenOver() throws {
        let (store, defaults) = try makeStore()
        defaults.set(Data("not json".utf8), forKey: DefaultsKey.rememberedLooks)
        let take = UUID()
        #expect(store.rememberedLook(forTake: take) == nil)
        store.setRememberedLook(look(exposure: 5), forTake: take)
        #expect(store.rememberedLook(forTake: take) == look(exposure: 5))
    }
}
