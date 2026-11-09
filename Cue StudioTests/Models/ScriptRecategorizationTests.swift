//
//  ScriptRecategorizationTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A script moved to another network takes its video along, unless it was posted or would merge into the new network's; versions for other
/// networks never move; Undo puts everything back (owner, 09/11/2026).
@MainActor
@Suite("ScriptRecategorization")
struct ScriptRecategorizationTests {
    private let script = UUID()

    private func take(_ number: Int, _ platform: Platform, exported: Bool = false, best: Bool = false) -> Take {
        var take = TestData.take(scriptID: script, number: number, isBest: best)
        take.platform = platform
        take.isExported = exported
        return take
    }

    // MARK: - The rule

    @Test func theOldNetworksVideoFollowsTheScript() {
        let takes = [take(1, .reels), take(2, .reels)]
        let change = ScriptRecategorization(takes: takes, from: .reels, to: .shorts) { _ in false }
        #expect(change.moving == Set(takes.map(\.id)))
        #expect(change.stay == nil)
        #expect(change.message == "Moved to Shorts")
    }

    @Test func aPostedVideoStays() {
        let posted = take(1, .reels)
        let change = ScriptRecategorization(takes: [posted, take(2, .reels)], from: .reels, to: .shorts) { $0.id == posted.id }
        #expect(change.moving.isEmpty)
        #expect(change.stay == .posted)
        #expect(change.message == "Moved to Shorts · Reels video stays (already posted)")
    }

    @Test func anExportedVideoCountsAsPosted() {
        let takes = [take(1, .reels, exported: true)]
        let shared: Set<UUID> = []
        let change = ScriptRecategorization(takes: takes, from: .reels, to: .shorts) { $0.isExported || shared.contains($0.id) }
        #expect(change.stay == .posted)
    }

    @Test func aVideoThatWouldMergeStays() {
        let change = ScriptRecategorization(takes: [take(1, .reels), take(2, .shorts)], from: .reels, to: .shorts) { _ in false }
        #expect(change.moving.isEmpty)
        #expect(change.stay == .newNetworkHasOne)
        #expect(change.message == "Moved to Shorts · Reels video stays (Shorts already has one)")
    }

    @Test func versionsForOtherNetworksNeverMove() {
        let reels = take(1, .reels), tiktok = take(2, .tiktok)
        let change = ScriptRecategorization(takes: [reels, tiktok], from: .reels, to: .shorts) { _ in false }
        #expect(change.moving == [reels.id])
        let none = ScriptRecategorization(takes: [tiktok], from: .reels, to: .shorts) { _ in false }
        #expect(none.moving.isEmpty && none.stay == nil && none.message == nil, "no video on the old network: the script just moves")
    }

    @Test func withoutTakesTheScriptJustMoves() {
        let change = ScriptRecategorization(takes: [], from: .reels, to: .shorts) { _ in false }
        #expect(change.moving.isEmpty && change.message == nil)
    }

    // MARK: - The script page

    private struct Scenario {
        let viewModel: ScriptDetailViewModel
        let library: ScriptLibraryService
        let takes: TakeLibraryService
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario(platform: Platform, takes recorded: [Take], shared: Set<UUID> = []) -> Scenario {
        let defaults = TestDefaults()
        var script = TestData.script(platform: platform)
        script.id = self.script
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]), now: { TestData.now })
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: recorded))
        takes.load()
        let toast = ToastService()
        let viewModel = ScriptDetailViewModel(
            scriptID: script.id, library: library, takes: takes, preferences: PreferencesService(defaults: defaults.defaults),
            profile: CreatorProfileService(defaults: defaults.defaults), rules: TestData.rulesService(), writer: FakeScriptWriter(), toast: toast,
            sharedTakeIDs: { shared }
        )
        return Scenario(viewModel: viewModel, library: library, takes: takes, toast: toast, defaults: defaults)
    }

    @Test func movingTheScriptMovesItsVideoAndUndoPutsItAllBack() throws {
        let starred = take(1, .reels, best: true), other = take(2, .reels), variant = take(3, .tiktok)
        let scenario = makeScenario(platform: .reels, takes: [starred, other, variant])
        defer { scenario.defaults.tearDown() }
        let before = scenario.takes.takes
        scenario.viewModel.setPlatform(.shorts)
        #expect(scenario.library.script(id: script)?.platform == .shorts)
        #expect(scenario.takes.take(id: starred.id)?.platform == .shorts && scenario.takes.take(id: other.id)?.platform == .shorts)
        #expect(scenario.takes.take(id: variant.id)?.platform == .tiktok)
        #expect(scenario.takes.take(id: starred.id)?.isBest == true, "the star moves with its video")
        #expect(scenario.toast.message == "Moved to Shorts")
        let undo = try #require(scenario.toast.action)
        undo.perform()
        #expect(scenario.library.script(id: script)?.platform == .reels)
        #expect(scenario.takes.takes == before)
    }

    @Test func aPostedVideoStaysAndTheToastSaysWhy() {
        let posted = take(1, .reels)
        let scenario = makeScenario(platform: .reels, takes: [posted], shared: [posted.id])
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setPlatform(.shorts)
        #expect(scenario.library.script(id: script)?.platform == .shorts)
        #expect(scenario.takes.take(id: posted.id)?.platform == .reels)
        #expect(scenario.toast.message == "Moved to Shorts · Reels video stays (already posted)")
        #expect(scenario.toast.action != nil)
    }

    @Test func aScriptWithoutAVideoThereSaysTheNewNetworkAsBefore() {
        let scenario = makeScenario(platform: .reels, takes: [])
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setPlatform(.shorts)
        #expect(scenario.library.script(id: script)?.platform == .shorts)
        #expect(scenario.toast.message == "Create for YouTube Shorts")
        #expect(scenario.toast.action == nil)
    }
}
