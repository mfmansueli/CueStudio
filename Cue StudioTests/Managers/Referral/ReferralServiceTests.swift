//
//  ReferralServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The invites (DESIGN_PROJECT §60): the server's count becomes rewards once per friend, in the kind that fits the plan; a friend joins once,
/// before their first export; the first export reaches the server once, again if it couldn't; a creator who never invites never reaches it.
@MainActor
@Suite("Invites")
struct ReferralServiceTests {
    /// The world around the service, changed as a test goes on.
    @MainActor
    private final class World {
        let client = FakeReferralClient()
        let store = InMemoryReferralStateStore()
        var exportsUsed = 0
        var isPro = false
        var ultraOffered = false
        var proof: String? = "signed-pro"
        var applied = ReferralRewards()
        var toasts: [String] = []
        var now = TestData.now

        func service(client: ReferralClient?? = nil) -> ReferralService {
            ReferralService(
                store: store, client: client ?? self.client, hasExported: { self.exportsUsed > 0 }, isPro: { self.isPro },
                ultraOffered: { self.ultraOffered }, proof: { self.proof }, apply: { self.applied = $0 },
                announce: { self.toasts.append($0) }, now: { self.now }
            )
        }
    }

    @Test func eachFriendsFirstExportIsCreditedOnceAsThreeExports() async {
        let world = World()
        let referral = world.service()
        world.client.setFriends(1)
        await referral.refresh()
        #expect(referral.status?.code == "K7M2QX")
        #expect(world.applied.bonusExports == 3)
        #expect(world.toasts.count == 1)
        await referral.refresh()
        world.client.setFriends(3)
        await referral.refresh()
        #expect(world.applied.bonusExports == 9)
        #expect(world.toasts.count == 2)
        // Kept in the Keychain: a new launch applies them at once, without asking the server.
        let relaunched = world.service()
        #expect(relaunched.rewards.bonusExports == 9)
        #expect(world.client.statusCalls == 3)
    }

    @Test func onProWithUltraAFriendBringsFiveScriptsAndWhatWasCreditedStays() async {
        let world = World()
        let referral = world.service()
        world.client.setFriends(2)
        await referral.refresh()
        world.isPro = true
        world.ultraOffered = true
        #expect(referral.reward == .ultraScripts)
        world.client.setFriends(3)
        await referral.refresh()
        #expect(world.applied.bonusExports == 6)
        #expect(world.applied.bonusUltraScripts == 5)
        #expect(world.toasts.last?.contains("5") == true)
    }

    @Test func theServersVerifiedSplitIsWhatCountsAndTheProofGoesOnlyWhereScriptsAreTheReward() async {
        let world = World()
        let referral = world.service()
        world.client.status = ReferralStatus(
            code: "K7M2QX", joined: 3, activated: 3, rewarded: 3, limit: 5, friendsAsExports: 1, friendsAsUltraScripts: 0
        )
        await referral.refresh()
        #expect(world.client.proofs == [nil])
        #expect(world.applied.bonusExports == 3)
        // On Pro with Ultra AI, the proof goes, and the server (not this iPhone) decides each new friend's kind.
        world.isPro = true
        world.ultraOffered = true
        world.now = world.now.addingTimeInterval(ReferralService.refreshInterval + 1)
        world.client.status = ReferralStatus(
            code: "K7M2QX", joined: 4, activated: 4, rewarded: 4, limit: 5, friendsAsExports: 2, friendsAsUltraScripts: 2
        )
        await referral.refresh()
        #expect(world.client.proofs.last == "signed-pro")
        #expect(world.applied.bonusExports == 6 && world.applied.bonusUltraScripts == 10)
        #expect(world.toasts.count == 3)
    }

    @Test func rewardsStopAtFiveFriends() async {
        let world = World()
        let referral = world.service()
        world.client.setFriends(8)
        await referral.refresh()
        #expect(world.applied.bonusExports == 15)
        #expect(referral.status?.hasReachedLimit == true)
    }

    @Test func invitesAreOfferedWhereTheRewardFitsThePlan() {
        let world = World()
        #expect(world.service().isOffered)
        world.isPro = true
        // Pro's exports are unlimited: without Ultra AI there is nothing to give.
        #expect(!world.service().isOffered)
        world.ultraOffered = true
        #expect(world.service().isOffered)
        #expect(!world.service(client: .some(nil)).isOffered)
    }

    @Test func aFriendJoinsOnceBeforeTheirFirstExport() async {
        let world = World()
        let referral = world.service()
        #expect(referral.canJoin)
        #expect(await referral.join("not a code") == .unknown)
        #expect(world.client.joined.isEmpty)
        #expect(await referral.join("ABCDEF") == .unknown)
        #expect(await referral.join(" p4w-hnb ") == .joined)
        #expect(referral.joinedCode == "P4WHNB")
        #expect(!referral.canJoin)
        #expect(await referral.join("P4WHNB") == .already)
        #expect(world.client.joined == ["ABCDEF", "P4WHNB"])
    }

    @Test func theCreatorsOwnCodeIsNeverSent() async {
        let world = World()
        let referral = world.service()
        await referral.refresh()
        #expect(await referral.join("K7M2QX") == .own)
        #expect(world.client.joined.isEmpty)
    }

    @Test func aCodeCantBeTypedAfterAnExport() async {
        let world = World()
        world.exportsUsed = 1
        #expect(!world.service().canJoin)
        let pro = World()
        let referral = pro.service()
        await referral.exportDelivered()
        // A Pro export isn't counted by the quota: this iPhone keeps that one left.
        #expect(!referral.canJoin)
        #expect(pro.client.activations == 0)
    }

    @Test func aJoinedFriendsFirstExportReachesTheServerOnceAndAgainIfItCouldnt() async {
        let world = World()
        let referral = world.service()
        _ = await referral.join("P4WHNB")
        world.client.isOffline = true
        await referral.exportDelivered()
        #expect(world.client.activations == 0)
        world.client.isOffline = false
        // Cue comes back to the front.
        await referral.refreshIfInviting()
        #expect(world.client.activations == 1)
        await referral.exportDelivered()
        await referral.refreshIfInviting()
        #expect(world.client.activations == 1)
        // And a later launch, from the Keychain, doesn't send it again.
        await world.service().refreshIfInviting()
        #expect(world.client.activations == 1)
    }

    @Test func aCreatorWhoNeverInvitesNeverReachesTheServer() async {
        let world = World()
        let referral = world.service()
        await referral.refreshIfInviting()
        await referral.exportDelivered()
        #expect(world.client.statusCalls == 0)
        #expect(world.client.activations == 0)
        #expect(world.client.joined.isEmpty)
    }

    @Test func aCreatorWhoInvitesIsCountedAgainAtMostEveryTenMinutes() async {
        let world = World()
        let referral = world.service()
        await referral.refresh()
        await referral.refreshIfInviting()
        #expect(world.client.statusCalls == 1)
        world.now = world.now.addingTimeInterval(ReferralService.refreshInterval)
        await referral.refreshIfInviting()
        #expect(world.client.statusCalls == 2)
    }

    @Test func anUnreachableServerSaysSoAndCreditsNothing() async {
        let world = World()
        world.client.isOffline = true
        let referral = world.service()
        await referral.refresh()
        #expect(referral.loading == .failed)
        #expect(referral.status == nil)
        #expect(await referral.join("P4WHNB") == .offline)
        #expect(referral.joinedCode == nil)
    }

    @Test func aKeychainThatCantBeReadSendsAndCreditsNothing() async {
        let world = World()
        world.store.isUnreadable = true
        let referral = world.service()
        #expect(!referral.isOffered)
        #expect(!referral.canJoin)
        // Not "this iPhone already used a code": it can be tried again once the Keychain opens.
        #expect(await referral.join("P4WHNB") == .offline)
        #expect(world.client.joined.isEmpty)
        await referral.refresh()
        await referral.exportDelivered()
        #expect(world.client.statusCalls == 0)
        #expect(world.store.state == nil)
    }
}
