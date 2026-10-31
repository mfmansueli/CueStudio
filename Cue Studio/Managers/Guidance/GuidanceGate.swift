//
//  GuidanceGate.swift
//  Cue Studio
//

import Foundation

/// The one gatekeeper of what Cue suggests on its own (owner, 30/10/2026; `DESIGN_PROJECT.md` §27): it adds no rules of timing (each
/// suggestion keeps its own: `isQuiet`, the voyage, `VoiceQuestionScheduler`, `NotificationService`'s `introsThisSession`, `tipDays` and
/// `isForegroundBusy`) and only decides between them.
///
/// - One suggestion per place (Scripts, Takes): the creator's work left waiting goes first, then the voyage's next step, a My Cue Voice
///   question, the Ultra AI line (`GuidanceKind`). What is on screen keeps its place; only the line in the dock steps aside for a tip.
/// - After the creator closes one, nothing else takes its place on that screen for the rest of the session.
/// - A celebration is the end of a task: the sheets that ask something (the notifications' invitation, a tool's introduction) don't come
///   after one in the same session, and never in the session of the first recording.
///
/// A session starts at launch, and again when Cue comes back after half an hour away.
@MainActor
@Observable
final class GuidanceGate {
    static let sessionGap: TimeInterval = 30 * 60

    /// What is on screen in each place.
    private(set) var holders: [GuidancePlace: GuidanceKind] = [:]
    /// What is due in each place and waiting for its moment (the voyage's tip during its 1.2 s).
    private(set) var waiting: [GuidancePlace: Set<GuidanceKind>] = [:]
    /// The places where the creator closed a suggestion this session.
    private(set) var closedPlaces: Set<GuidancePlace> = []
    /// A celebration (a story, the send-off) played this session.
    private(set) var celebratedThisSession = false
    private(set) var sessionStartedAt: Date

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var leftAt: Date?

    init(now: @escaping () -> Date = { .now }) {
        self.now = now
        sessionStartedAt = now()
    }

    // MARK: - Sessions

    /// Cue left the screen.
    func appLeftScreen() {
        leftAt = now()
    }

    /// Cue is on screen again: half an hour away or more starts a new session (closed places and celebrations are forgotten).
    func appBecameActive() {
        defer { leftAt = nil }
        guard let leftAt, now().timeIntervalSince(leftAt) >= Self.sessionGap else { return }
        sessionStartedAt = now()
        closedPlaces = []
        celebratedThisSession = false
    }

    /// `date` (a first take's) is in an earlier session than this one.
    func isBeforeThisSession(_ date: Date) -> Bool { date < sessionStartedAt }

    // MARK: - One suggestion per place

    /// Whether `kind` may be on screen at `place` now.
    func mayShow(_ kind: GuidanceKind, at place: GuidancePlace) -> Bool {
        if kind.isSuggestion, closedPlaces.contains(place) { return false }
        if let holder = holders[place], holder != kind { return holder.yields(to: kind) }
        let ahead = (waiting[place] ?? []).filter { $0 < kind }
        if holders[place] == kind { return !ahead.contains { kind.yields(to: $0) } }
        return ahead.isEmpty
    }

    /// `kind` is due at `place` (or no longer is) and waits for its moment: what comes after it waits too.
    func setWaiting(_ kind: GuidanceKind, at place: GuidancePlace, _ isWaiting: Bool) {
        var set = waiting[place] ?? []
        guard set.contains(kind) != isWaiting else { return }
        if isWaiting { set.insert(kind) } else { set.remove(kind) }
        waiting[place] = set
    }

    /// `kind` came on screen at `place`.
    func shown(_ kind: GuidanceKind, at place: GuidancePlace) {
        guard holders[place] != kind else { return }
        holders[place] = kind
    }

    /// `kind` left `place`: acted on, gone with its reason, or closed by the creator (`closed`), which keeps the place quiet for the session.
    func left(_ kind: GuidanceKind, at place: GuidancePlace, closed: Bool = false) {
        if holders[place] == kind { holders[place] = nil }
        if closed { closedPlaces.insert(place) }
    }

    /// The creator asked for the guidance again (the first video guide switched back on): the places closed this session open again.
    func reopenPlaces() {
        closedPlaces = []
    }

    // MARK: - Celebrations and the sheets that ask

    /// A story or the send-off ended.
    func celebrated() {
        celebratedThisSession = true
    }

    /// The notifications' invitation or a tool's introduction may come up after a session at the camera: not after a celebration in this
    /// session, and, for the invitation (`firstTakeAt`: the creator's first take), never in the session of their first recording.
    func mayAsk(firstTakeAt: Date?) -> Bool {
        guard !celebratedThisSession else { return false }
        guard let firstTakeAt else { return true }
        return isBeforeThisSession(firstTakeAt)
    }
}
