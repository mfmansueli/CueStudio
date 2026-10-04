//
//  RecordingBarState.swift
//  Cue Studio
//

import Foundation

/// While a take records, the controls shrink to a compact bar (so the text and the frame are what
/// the creator sees). Tapping the screen shows the whole bar for a few seconds, and every use of
/// it starts the count again.
@MainActor
@Observable
final class RecordingBarState {
    private(set) var isExpanded = false
    /// How long the whole bar stays after a tap or a touch of one of its controls.
    var expandedDuration: Duration = .seconds(4)

    /// When the count last started (a tap, or a touch long enough after the last one).
    private(set) var lastArmed = ContinuousClock.now
    /// A touch sooner than this after the count started doesn't restart it.
    static let rearmThreshold: Duration = .milliseconds(500)

    private var collapseTask: Task<Void, Never>?

    /// Shows the whole bar and counts `expandedDuration` from now.
    func expand(at now: ContinuousClock.Instant = .now) {
        isExpanded = true
        lastArmed = now
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            guard let duration = self?.expandedDuration else { return }
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.isExpanded = false
        }
    }

    /// A control of the whole bar was used: it stays a little longer. Does nothing when the bar
    /// isn't open, and a drag (a slider) doesn't restart the count on every point it moves through.
    func touch(at now: ContinuousClock.Instant = .now) {
        guard isExpanded, lastArmed.duration(to: now) > Self.rearmThreshold else { return }
        expand(at: now)
    }

    /// Back to the compact bar now (a take starts or stops).
    func collapse() {
        collapseTask?.cancel()
        collapseTask = nil
        isExpanded = false
    }
}
