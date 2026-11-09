//
//  ReferralService.swift
//  Cue Studio
//

import Foundation

/// Cue's invites (owner, 05/11/2026; DESIGN_PROJECT §60). A creator shares their code; a friend types it before their first export; when that
/// friend exports their first video, the creator earns 3 more exports (on Cue Pro, where Ultra AI is offered, 5 more Ultra AI scripts), for up
/// to 5 friends. Only the creator who invites is rewarded (App Review has refused apps that reward the one who downloads).
///
/// The server alone counts who joined and who exported (`ReferralClient`); this service turns its count into rewards, once per friend, and
/// keeps them in the Keychain (`ReferralStateStoring`) with the install's random id. Cue asks the server only for a creator who opened their
/// invites, a friend who typed a code, and that friend's first export: a creator who never invites never reaches it.
@MainActor
@Observable
final class ReferralService {
    enum Loading: Equatable, Sendable {
        case idle
        case loading
        /// The server couldn't be reached.
        case failed
    }

    /// The creator's invites, as last read (shown at once while a fresh count loads).
    private(set) var status: ReferralStatus?
    private(set) var loading: Loading = .idle
    private(set) var rewards = ReferralRewards()
    /// The code this iPhone joined with, as a friend.
    private(set) var joinedCode: String?
    /// The Keychain couldn't be read at launch (Cue woke before the first unlock): nothing is sent or credited until the next launch.
    private(set) var isReadable = true

    /// A creator who looks at their invites at most this often makes the server count again.
    static let refreshInterval: TimeInterval = 10 * 60

    @ObservationIgnored private var state: ReferralLocalState?
    @ObservationIgnored private var lastRefresh: Date?
    @ObservationIgnored private let store: ReferralStateStoring
    @ObservationIgnored private let client: ReferralClient?
    @ObservationIgnored private let hasExported: @MainActor () -> Bool
    @ObservationIgnored private let isPro: @MainActor () -> Bool
    @ObservationIgnored private let ultraOffered: @MainActor () -> Bool
    @ObservationIgnored private let proof: @MainActor () async -> String?
    @ObservationIgnored private let apply: @MainActor (ReferralRewards) -> Void
    @ObservationIgnored private let announce: @MainActor (String) -> Void
    @ObservationIgnored private let now: () -> Date
    /// "Help improve Cue" on: the invites are measured (`TelemetryManager`).
    @ObservationIgnored var report: (@MainActor (ReferralTelemetryEvent) -> Void)?

    /// - Parameters:
    ///   - client: Cue's server; nil where Firebase doesn't run (tests, previews), and then invites aren't offered.
    ///   - hasExported: whether a video of this iPhone ever left Cue (a friend joins only before that).
    ///   - proof: the App Store's signed Pro transaction (`StoreManager.proProof`), sent where friends would be Ultra AI scripts: the server
    ///     credits them so only on a Pro it verified.
    ///   - apply: hands the rewards to the free exports' count and to Ultra AI's allowance, at launch and whenever they grow.
    ///   - announce: says a new reward (a toast).
    init(
        store: ReferralStateStoring, client: ReferralClient?, hasExported: @escaping @MainActor () -> Bool,
        isPro: @escaping @MainActor () -> Bool, ultraOffered: @escaping @MainActor () -> Bool,
        proof: @escaping @MainActor () async -> String? = { nil },
        apply: @escaping @MainActor (ReferralRewards) -> Void, announce: @escaping @MainActor (String) -> Void,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.client = client
        self.hasExported = hasExported
        self.isPro = isPro
        self.ultraOffered = ultraOffered
        self.proof = proof
        self.apply = apply
        self.announce = announce
        self.now = now
        do {
            state = try store.load()
        } catch {
            isReadable = false
        }
        publish()
    }

    // MARK: - Reading

    /// Invites are offered where the server can be reached and the reward fits the plan: exports on the free plan, Ultra AI scripts on Pro
    /// where Ultra AI is offered (Pro's exports are unlimited already).
    var isOffered: Bool { client != nil && isReadable && (!isPro() || ultraOffered()) }

    /// A friend may still type a code: once, before this iPhone's first export.
    var canJoin: Bool { client != nil && isReadable && joinedCode == nil && state?.delivered != true && !hasExported() }

    /// What one friend's first export earns this creator now.
    var reward: ReferralReward { isPro() && ultraOffered() ? .ultraScripts : .exports }

    // MARK: - The creator who invites

    /// The creator's code (made on the first call) and a fresh count of their friends; new rewards are credited and said.
    func refresh() async {
        guard let client, loading != .loading, let installID = ensuredInstallID() else { return }
        loading = .loading
        do {
            let asUltraScripts = isPro() && ultraOffered()
            let fresh = try await client.status(installID: installID, proof: asUltraScripts ? await proof() : nil)
            lastRefresh = now()
            loading = .idle
            var before = ReferralRewards()
            var after = ReferralRewards()
            update { state in
                state.status = fresh
                before = state.rewards
                state.rewards.adopt(fresh, asUltraScripts: asUltraScripts)
                after = state.rewards
            }
            let newExports = max(0, after.friendsAsExports - before.friendsAsExports)
            let newUltra = max(0, after.friendsAsUltraScripts - before.friendsAsUltraScripts)
            for (friends, asUltra) in [(newExports, false), (newUltra, true)] where friends > 0 {
                announce(Self.rewardMessage(friends: friends, asUltraScripts: asUltra))
                report?(ReferralTelemetryEvent(step: .rewarded, outcome: asUltra ? "ultra" : "exports", count: friends))
            }
        } catch {
            loading = .failed
        }
    }

    /// At launch and when Cue comes back: a friend's first export that didn't reach the server is sent again, and a creator who invites gets
    /// their count, at most every `refreshInterval`. A creator who never opened their invites never reaches the server.
    func refreshIfInviting() async {
        if joinedCode != nil, state?.activationSent == false, state?.delivered == true { await exportDelivered() }
        guard status != nil, lastRefresh.map({ now().timeIntervalSince($0) >= Self.refreshInterval }) ?? true else { return }
        await refresh()
    }

    // MARK: - The friend

    /// A friend typed a code. Checked here first (its shape, the creator's own), then by the server.
    func join(_ typed: String) async -> ReferralJoinOutcome {
        let outcome = await joining(typed)
        report?(ReferralTelemetryEvent(step: .joined, outcome: outcome.rawValue))
        return outcome
    }

    private func joining(_ typed: String) async -> ReferralJoinOutcome {
        guard let code = ReferralCode.normalized(typed) else { return .unknown }
        // No server, a Keychain not readable yet (before the first unlock) or no install id: something to try again, not "already used".
        guard let client, isReadable, let installID = ensuredInstallID() else { return .offline }
        guard canJoin else { return .already }
        if status?.code == code { return .own }
        do {
            let outcome = try await client.join(installID: installID, code: code)
            if outcome == .joined || outcome == .already { update { $0.joinedCode = code } }
            return outcome
        } catch {
            return .offline
        }
    }

    /// An invite offered or opened, a code copied or shared: measured.
    func note(_ step: ReferralTelemetryEvent.Step, at place: ReferralTelemetryEvent.Place? = nil) {
        report?(ReferralTelemetryEvent(step: step, place: place))
    }

    /// A video of this iPhone left Cue (`ExportLedgerService.firstDelivered`): from now on no code can be typed, and if a creator invited this
    /// iPhone, the server counts their reward. When it can't be reached, `refreshIfInviting` sends it again.
    func exportDelivered() async {
        if state?.delivered != true { update { $0.delivered = true } }
        guard let client, joinedCode != nil, state?.activationSent == false, let installID = state?.installID else { return }
        do {
            try await client.activate(installID: installID)
            update { $0.activationSent = true }
        } catch {
            return
        }
    }

    // MARK: - Private

    /// The install's random id, made the first time: the one Ultra AI's calls name too (`UltraCallerSource`), so the scripts invites earned
    /// and the scripts written are counted for the same install. Nil while the Keychain can't be read.
    func installIdentity() -> UUID? {
        ensuredInstallID()
    }

    private func ensuredInstallID() -> UUID? {
        guard isReadable else { return nil }
        if state == nil { update { _ in } }
        return state?.installID
    }

    private func update(_ change: (inout ReferralLocalState) -> Void) {
        guard isReadable else { return }
        var next = state ?? ReferralLocalState(installID: UUID())
        change(&next)
        state = next
        store.save(next)
        publish()
    }

    private func publish() {
        status = state?.status
        rewards = state?.rewards ?? ReferralRewards()
        joinedCode = state?.joinedCode
        apply(rewards)
    }

    nonisolated static func rewardMessage(friends: Int, asUltraScripts: Bool) -> String {
        if asUltraScripts {
            let scripts = friends * ReferralRewards.ultraScriptsPerFriend
            return friends == 1
                ? String(localized: "A friend you invited exported their first video · +\(scripts) Ultra AI scripts")
                : String(localized: "\(friends) friends you invited exported their first video · +\(scripts) Ultra AI scripts")
        }
        let exports = friends * ReferralRewards.exportsPerFriend
        return friends == 1
            ? String(localized: "A friend you invited exported their first video · +\(exports) exports")
            : String(localized: "\(friends) friends you invited exported their first video · +\(exports) exports")
    }
}
