//
//  ReferralModelsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The invites' pure parts: the code as a friend types it, the rewards per friend, the words, the App Store link and the rating prompt's rules.
@Suite("Invites: models")
struct ReferralModelsTests {
    @Test func aTypedCodeIsReadWithoutSpacesDashesOrCase() {
        #expect(ReferralCode.normalized(" k7m-2qx ") == "K7M2QX")
        #expect(ReferralCode.normalized("K7M 2QX") == "K7M2QX")
        // The server's alphabet has no I, O, 0 or 1.
        #expect(ReferralCode.normalized("K7M2Q0") == nil)
        #expect(ReferralCode.normalized("K7M2Q") == nil)
        #expect(ReferralCode.normalized("K7M2QXX") == nil)
        #expect(InviteCodeCard.spaced("K7M2QX") == "K7M\u{2009}2QX")
    }

    @Test func eachFriendIsCreditedOnceInTheKindOfItsDay() {
        var rewards = ReferralRewards()
        #expect(rewards.credit(rewarded: 2, asUltraScripts: false) == 2)
        #expect(rewards.credit(rewarded: 2, asUltraScripts: true) == 0)
        #expect(rewards.credit(rewarded: 3, asUltraScripts: true) == 1)
        #expect(rewards.bonusExports == 6)
        #expect(rewards.bonusUltraScripts == 5)
        // The server never counts down, but if it did nothing would be taken back.
        #expect(rewards.credit(rewarded: 1, asUltraScripts: false) == 0)
        #expect(rewards.friendsCredited == 3)
    }

    @Test func theProgressSaysWhatEachFriendWasCreditedAs() {
        var rewards = ReferralRewards()
        _ = rewards.credit(rewarded: 2, asUltraScripts: false)
        #expect(InviteCopy.progress(rewarded: 2, limit: 5, rewards: rewards) == "2 of 5 friends · +6 exports")
        _ = rewards.credit(rewarded: 3, asUltraScripts: true)
        #expect(InviteCopy.progress(rewarded: 3, limit: 5, rewards: rewards) == "3 of 5 friends · +6 exports · +5 Ultra AI scripts")
        #expect(InviteCopy.progress(rewarded: 0, limit: 5, rewards: ReferralRewards()) == "0 of 5 friends")
    }

    @Test func theHeadlineSaysWhatOneFriendBringsUntilAllHaveCounted() {
        var rewards = ReferralRewards()
        #expect(InviteCopy.headline(.exports, rewards: rewards, isComplete: false) == "+3 exports")
        #expect(InviteCopy.headline(.ultraScripts, rewards: rewards, isComplete: false) == "+5 Ultra AI scripts")
        _ = rewards.credit(rewarded: 5, asUltraScripts: false)
        #expect(InviteCopy.headline(.exports, rewards: rewards, isComplete: true) == "+15 exports")
        #expect(InviteCopy.rewardStep(.exports).hasSuffix("+3 exports"))
        #expect(InviteCopy.rewardStep(.ultraScripts).hasSuffix("+5 Ultra AI scripts"))
    }

    @Test func theMessageCarriesTheCodeAndTheLinkWhenThereIsOne() throws {
        let link = try #require(AppStoreLink.url(appID: "6741234567"))
        #expect(link.absoluteString == "https://apps.apple.com/app/id6741234567")
        let message = InviteCopy.message(code: "K7M2QX", link: link)
        #expect(message.contains("K7M2QX"))
        #expect(message.contains(link.absoluteString))
        #expect(InviteCopy.message(code: "K7M2QX", link: nil).contains("App Store"))
        // A note, not a bare link: what Cue does, the link, then where and when to type the code, the code last.
        let paragraphs = message.components(separatedBy: "\n\n")
        #expect(paragraphs.count == 3)
        #expect(paragraphs[0].contains("Cue Studio") && !paragraphs[0].contains("http"))
        #expect(paragraphs[2].contains("Profile › Invite friends") && paragraphs[2].hasSuffix("K7M2QX"))
        #expect(AppStoreLink.url(appID: "") == nil)
        #expect(AppStoreLink.url(appID: "$(CUE_APP_STORE_ID)") == nil)
        #expect(AppStoreLink.url(appID: "١٢٣") == nil)
    }

    @Test func everyAnswerButJoinedSaysWhatToDo() {
        #expect(InviteCopy.joinAnswer(.joined) == nil)
        for outcome in [ReferralJoinOutcome.unknown, .own, .already, .offline] {
            #expect(InviteCopy.joinAnswer(outcome)?.isEmpty == false)
        }
    }

    @Test func theRatingIsAskedOnALaterDayAfterTheSecondVideoOncePerVersion() {
        var policy = ReviewPromptPolicy(installDay: "2026-11-5")
        policy.deliveries = 1
        #expect(!policy.asks(today: "2026-11-6", version: "1.0", exportsLeft: 2))
        policy.deliveries = 2
        #expect(!policy.asks(today: "2026-11-5", version: "1.0", exportsLeft: 1))
        #expect(policy.asks(today: "2026-11-6", version: "1.0", exportsLeft: 1))
        #expect(policy.asks(today: "2026-11-6", version: "1.0", exportsLeft: nil))
        // Never when the free exports just ran out, on a day an export failed, or again in the same version.
        #expect(!policy.asks(today: "2026-11-6", version: "1.0", exportsLeft: 0))
        policy.failureDay = "2026-11-6"
        #expect(!policy.asks(today: "2026-11-6", version: "1.0", exportsLeft: 1))
        policy.failureDay = nil
        policy.askedVersion = "1.0"
        #expect(!policy.asks(today: "2026-11-7", version: "1.0", exportsLeft: 1))
        #expect(policy.asks(today: "2026-11-7", version: "1.1", exportsLeft: 1))
    }
}
