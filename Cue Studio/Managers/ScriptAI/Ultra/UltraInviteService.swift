//
//  UltraInviteService.swift
//  Cue Studio
//

import Foundation

/// The invitation to try Ultra AI (owner, 29/10/2026): from the second time the creator uses Cue's AI (a script Apple Intelligence wrote, a visit to
/// Find inspiration), the places where AI writes (the Scripts dock, Find inspiration, My Cue Voice) offer Ultra AI and its free scripts. One
/// invitation for all of them: closed in one place, it is closed everywhere. `UltraScriptService.showsInvite` adds the rest (Ultra offered, not
/// allowed yet, scripts left).
@MainActor
@Observable
final class UltraInviteService {
    static let usesKey = "ultraInvite.aiUses.v1"
    static let closedKey = "ultraInvite.closed.v1"
    /// Uses of the AI before the invitation: it comes with the second.
    static let usesBefore = 1

    private(set) var aiUses: Int
    private(set) var isClosed: Bool
    @ObservationIgnored private let defaults: UserDefaults
    /// Where the invitation has already lit up in this session (`UltraInviteCard`): it lights up once per place, not each time it comes back.
    @ObservationIgnored private var arrivals: Set<String> = []

    init(defaults: UserDefaults) {
        self.defaults = defaults
        aiUses = defaults.integer(forKey: Self.usesKey)
        isClosed = defaults.bool(forKey: Self.closedKey)
    }

    /// The creator has used the AI before, and hasn't closed the invitation.
    var isDue: Bool { !isClosed && aiUses >= Self.usesBefore }

    /// Apple Intelligence wrote something for the creator. Counted up to the point where it matters.
    func noteAIUse() {
        guard aiUses < Self.usesBefore else { return }
        aiUses += 1
        defaults.set(aiUses, forKey: Self.usesKey)
    }

    /// True the first time the invitation appears at `place` in this session: it lights up then, and is simply there afterwards.
    func takesArrival(of place: String) -> Bool {
        arrivals.insert(place).inserted
    }

    /// "Not now" on any of the invitations.
    func close() {
        isClosed = true
        defaults.set(true, forKey: Self.closedKey)
    }

    /// The lab's "Show the invitation again" (Debug): due again from the next visit, as if the AI had been used once.
    func reopen() {
        isClosed = false
        aiUses = Self.usesBefore
        defaults.removeObject(forKey: Self.closedKey)
        defaults.set(aiUses, forKey: Self.usesKey)
    }
}
