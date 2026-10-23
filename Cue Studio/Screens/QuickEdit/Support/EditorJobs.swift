//
//  EditorJobs.swift
//  Cue Studio
//

import Foundation

/// The work Quick edit starts and waits for, all in one place: one job of each kind runs at a time (a new one cancels the
/// one before, whose result is then dropped), tools' jobs run side by side, and closing the editor cancels every one. A job
/// hands its result back only while its ticket is still current (`isCurrent`): not after a newer one started, after it was
/// cancelled, or once the editor closed.
@MainActor
final class EditorJobs {
    /// What a job does. One of each runs at a time, except tools' jobs (a freeze frame, a reverse, a sound pulled out) and
    /// beats (one per music file).
    nonisolated enum Kind: Hashable, Sendable {
        /// Auto measuring the picture (Adjust).
        case auto
        /// Listening to the take for captions.
        case captions
        /// Track following an object.
        case tracking
        /// Drawing the cover for the timeline's cover block.
        case cover
        /// A short part playing to show a change.
        case preview
        /// Measuring the untreated sound for Studio Voice's Compare.
        case comparison
        /// The draft written a moment after a change.
        case draft
        /// A short word said once a sheet has gone.
        case notice
        /// Finding the beats of one music file.
        case beats(String)
        /// Clean Up listening to the recordings.
        case cleanUp
        /// A tool's work (`startTool`).
        case tool(UUID)
    }

    /// One run of a job: its result counts while it is current.
    nonisolated struct Ticket: Hashable, Sendable {
        let kind: Kind
        let id = UUID()
    }

    private var running: [Kind: (ticket: Ticket, task: Task<Void, Never>)] = [:]
    /// The editor closed: nothing starts any more and what finishes late is dropped.
    private(set) var isClosed = false

    /// Starts `work` as the job of `kind`, cancelling the one already running; nil once the editor closed. `work` gets its
    /// ticket, to check before it hands anything back.
    @discardableResult
    func start(_ kind: Kind, _ work: @escaping @MainActor (Ticket) async -> Void) -> Ticket? {
        guard !isClosed else { return nil }
        cancel(kind)
        let ticket = Ticket(kind: kind)
        let task = Task { [weak self] in
            await work(ticket)
            self?.finished(ticket)
        }
        running[kind] = (ticket, task)
        return ticket
    }

    /// Starts a tool's work, side by side with any other tool's.
    @discardableResult
    func startTool(_ work: @escaping @MainActor () async -> Void) -> Ticket? {
        start(.tool(UUID())) { _ in await work() }
    }

    /// Whether `ticket`'s result is still wanted.
    func isCurrent(_ ticket: Ticket) -> Bool {
        !isClosed && running[ticket.kind]?.ticket == ticket
    }

    func isRunning(_ kind: Kind) -> Bool {
        running[kind] != nil
    }

    /// Waits for the job of `kind` running now, if there is one.
    func finished(_ kind: Kind) async {
        await running[kind]?.task.value
    }

    /// Stops the job of `kind`; whatever it finds later is dropped.
    func cancel(_ kind: Kind) {
        running.removeValue(forKey: kind)?.task.cancel()
    }

    /// The editor closes: every job is cancelled and none starts again.
    func close() {
        isClosed = true
        for job in running.values { job.task.cancel() }
        running = [:]
    }

    private func finished(_ ticket: Ticket) {
        if running[ticket.kind]?.ticket == ticket { running[ticket.kind] = nil }
    }
}
