//
//  UltraAllowanceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Ultra AI's scripts (owner, 29/10 and 30/10/2026): three free ones for everyone; thirty a month more with Pro; the
/// free ones are spent first; a script is counted only once written; the preview's counts and the invitation to try it.
@MainActor
@Suite("Ultra AI allowance")
struct UltraAllowanceTests {
    /// The creator's plan and the date, changed as a test goes on.
    private final class Plan {
        var membership = UltraAllowance.Membership.free
        var now = TestData.now
    }

    @Test func everyoneGetsThreeFreeAndProAddsThirtyAMonth() {
        #expect(UltraAllowance(membership: .free, freeUsed: 0, monthUsed: 0).left == 3)
        #expect(UltraAllowance(membership: .paid, freeUsed: 0, monthUsed: 0).left == 33)
        #expect(UltraAllowance(membership: .paid, freeUsed: 3, monthUsed: 30).left == 0)
        #expect(UltraAllowance(membership: .free, freeUsed: 9, monthUsed: 0).left == 0)
    }

    @Test func theFreeOnesAreSpentFirst() {
        var allowance = UltraAllowance(membership: .paid, freeUsed: 2, monthUsed: 0)
        allowance = allowance.spending()
        #expect(allowance.freeUsed == 3 && allowance.monthUsed == 0)
        allowance = allowance.spending()
        #expect(allowance.freeUsed == 3 && allowance.monthUsed == 1 && allowance.left == 29)
    }

    @Test func nothingLeftStaysNothingLeft() {
        let used = UltraAllowance(membership: .free, freeUsed: 3, monthUsed: 0)
        #expect(used.spending() == used)
    }

    @Test func theMembershipFollowsTheStore() {
        #expect(UltraAllowance.Membership(tier: .free) == .free)
        #expect(UltraAllowance.Membership(tier: .subscriber) == .paid)
    }

    @Test func thePreviewCountsWhatWasWrittenAndANewMonthBringsProsBack() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let plan = Plan()
        let service = UltraAllowanceService(defaults: defaults.defaults, membership: { plan.membership }, now: { plan.now })
        for _ in 0..<3 { service.spend() }
        #expect(service.left == 0)
        plan.membership = .paid
        #expect(service.left == 30)
        service.spend()
        #expect(service.left == 29)
        // Read again from the defaults: the count is kept.
        #expect(UltraAllowanceService(defaults: defaults.defaults, membership: { plan.membership }, now: { plan.now }).left == 29)
        plan.now = Calendar.current.date(byAdding: .month, value: 1, to: plan.now) ?? plan.now
        #expect(service.left == 30)
    }

    @Test func theLabGivesTheFreeOnesBack() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = UltraAllowanceService(defaults: defaults.defaults, membership: { .free })
        service.spend()
        service.spend()
        #expect(service.left == 1)
        service.resetPreview()
        #expect(service.left == 3)
        service.setFreeLeft(1)
        #expect(service.left == 1)
    }

    @Test func eachPlaceSaysWhatIsLeft() {
        let fresh = UltraAllowance(membership: .free, freeUsed: 0, monthUsed: 0)
        let used = UltraAllowance(membership: .free, freeUsed: 1, monthUsed: 0)
        let pro = UltraAllowance(membership: .paid, freeUsed: 3, monthUsed: 2)
        #expect(UltraAllowanceLabels.consent(fresh) == "Your first 3 scripts are free.")
        #expect(UltraAllowanceLabels.consent(used) == "2 of 3 free scripts left.")
        #expect(UltraAllowanceLabels.consent(pro) == "28 scripts left this month.")
        #expect(UltraAllowanceLabels.menu(used) == "Ultra AI · 2 of 3 free left")
        #expect(UltraAllowanceLabels.menu(pro) == "Ultra AI · 28 left this month")
        #expect(UltraAllowanceLabels.plan(used) == "ULTRA AI · 2 OF 3 FREE LEFT")
    }

    // MARK: - Invitation

    @Test func theInvitationIsDueFromTheSecondUseUntilClosed() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let invite = UltraInviteService(defaults: defaults.defaults)
        #expect(!invite.isDue)
        invite.noteAIUse()
        #expect(invite.isDue)
        invite.close()
        #expect(!invite.isDue)
        // Closed in one place, closed in all: another screen reads the same.
        #expect(!UltraInviteService(defaults: defaults.defaults).isDue)
        invite.reopen()
        #expect(invite.isDue)
    }

    @Test func theInvitationShowsOnlyWhereUltraIsOfferedNotAllowedAndWithScriptsLeft() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let consent = UltraConsentService(defaults: defaults.defaults)
        let invite = UltraInviteService(defaults: defaults.defaults)
        let allowance = UltraAllowanceService(defaults: defaults.defaults, membership: { .free })
        let budget = UltraCallBudget(defaults: defaults.defaults)
        let make = { (available: Bool) in
            UltraScriptService(isAvailable: available, consent: consent, budget: budget, allowance: allowance, invite: invite) { nil }
        }
        #expect(!make(true).showsInvite)
        make(true).noteAIUse()
        #expect(make(true).showsInvite)
        #expect(!make(false).showsInvite)
        allowance.setFreeLeft(0)
        #expect(!make(true).showsInvite)
        allowance.resetPreview()
        consent.grant()
        #expect(!make(true).showsInvite)
    }

    /// Invites on Pro (§60): five scripts per friend, kept with the free ones (they don't end with the month).
    @Test func scriptsInvitesEarnedAreFreeOnesThatOutliveTheMonth() {
        let allowance = UltraAllowance(membership: .paid, freeUsed: 3, monthUsed: 30, bonus: 5)
        #expect(allowance.freeTotal == 8)
        #expect(allowance.left == 5)
        #expect(UltraAllowanceLabels.plan(UltraAllowance(membership: .free, freeUsed: 1, monthUsed: 0, bonus: 5)) == "ULTRA AI · 7 OF 8 FREE LEFT")
    }
}
