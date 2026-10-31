//
//  ToastService.swift
//  Cue Studio
//

import SwiftUI

/// Short confirmations shown at the top of whatever screen is in front, one at a time, each with its kind (`ToastKind`).
///
/// Two ways in, and no queue (a queue would make the editor's Undo undo something else, `comunicacao-revisao` §4):
/// - `show`: the answer to what the creator just did. It takes the place of whatever is up: in the editor the toast's Undo is "undo the
///   last change", so the newest wins.
/// - `showResult`: what came of work that took a while (an AI version, a rewrite, an export). It never takes the place of a toast with a
///   button (an Undo, Try again, Settings): it waits for that one to go, then comes in. Only the newest waiting result is kept.
///
/// A working toast (`showWorking`) ends only with its own result (`ending:` its pill): a toast from another operation comes in its own
/// pill, with no success tap, so it can never read as the work having ended.
@MainActor
@Observable
final class ToastService {
    private(set) var message: String?
    private(set) var kind: ToastKind = .done
    /// The button beside the message, when the toast has one.
    private(set) var action: ToastAction?
    /// The pill on screen: a new one for every toast, except the toast that ends work under way, which takes its own working
    /// toast's place in the same pill (its ring becomes the new icon, its words the new ones).
    private(set) var pill = UUID()
    /// How long a toast stays when none is given: the editor's last 2 s.
    var defaultDuration: Duration = .seconds(2.4)
    /// How long a toast with a button ("Undo") stays when none is given: long enough to reach it.
    static let actionDuration: Duration = .seconds(4)
    /// How long work under way can keep its ring turning with nothing said: a piece of work that ends in silence lets its toast go
    /// (`endWorking`), and this is the floor under one that never says.
    static let workingLimit: Duration = .seconds(60)
    /// When the tap of a kind lands, from the toast's arrival: as the ✓ starts to draw and the ! to shake, at the ★'s widest.
    static let tapDelay: Duration = .milliseconds(200)
    static let cueTapDelay: Duration = .milliseconds(350)
    /// Sheets that show the toast themselves (`toastHost(inSheet: true)`), counted while they are up: the root's host leaves the toast to
    /// them, so it is shown once, in front, and never half under a sheet.
    private(set) var sheetHosts = 0
    /// Called when the toast leaves, for whoever waits on it (`onLeave`): a deleted take's video is purged only once its Undo is gone.
    @ObservationIgnored private var leaveHandlers: [UUID: () -> Void] = [:]
    /// A result that arrived while a toast with a button was up (`showResult`): it comes in when that toast goes.
    private var waiting: Waiting?
    private var dismissTask: Task<Void, Never>?
    private var tapTask: Task<Void, Never>?

    private struct Waiting {
        let message: String
        let kind: ToastKind
        let duration: Duration?
        let action: ToastAction?
    }

    /// The words of the result waiting for a toast with a button to go.
    var waitingResult: String? { waiting?.message }

    /// A toast with a button is up: what it offers (Undo, Try again, Settings) is still within reach.
    var holdsAButton: Bool { message != nil && action != nil }

    func sheetHostAppeared() { sheetHosts += 1 }

    func sheetHostDisappeared() { sheetHosts = max(0, sheetHosts - 1) }

    /// The answer to what the creator just did: it takes the place of whatever is up. `ending` is the pill `showWorking` returned when
    /// this is what came of that work: only then does it take the ring's place in the same pill, with the success tap.
    func show(
        _ message: String, kind: ToastKind = .done, duration: Duration? = nil, action: ToastAction? = nil, ending work: UUID? = nil
    ) {
        let endsWork = work != nil && work == pill && self.message != nil && self.kind == .working && kind != .working
        let leaving = self.message == nil ? nil : pill
        if !endsWork { pill = UUID() }
        let duration = kind == .working ? Self.workingLimit : self.duration(for: duration, hasAction: action != nil)
        dismissTask?.cancel()
        self.message = message
        self.kind = kind
        self.action = action
        AccessibilityNotification.Announcement(message).post()
        tap(for: kind, endsWork: endsWork)
        if let leaving, leaving != pill { left(leaving) }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    /// What came of work that took a while (an AI version, a rewrite, an export): shown now, unless a toast with a button is up, which
    /// it never replaces (that Undo may be the only way back): it then comes in as soon as that toast goes. `ending`, as in `show`.
    func showResult(
        _ message: String, kind: ToastKind = .done, duration: Duration? = nil, action: ToastAction? = nil, ending work: UUID? = nil
    ) {
        guard holdsAButton else {
            show(message, kind: kind, duration: duration, action: action, ending: work)
            return
        }
        // A toast with a button is up, so its own working toast (if any) was taken over meanwhile: there is no ring left to end.
        waiting = Waiting(message: message, kind: kind, duration: duration, action: action)
    }

    /// Work under way ("Freezing the frame…"), with the turning ring. Its own result (`show(…, ending:)` with the pill returned) takes
    /// its place in the same pill; when the work ends with nothing to say, `endWorking` with the pill lets it go.
    @discardableResult
    func showWorking(_ message: String) -> UUID {
        show(message, kind: .working)
        return pill
    }

    /// Lets the working toast of `pill` go, unless what came of the work already took its place.
    func endWorking(_ pill: UUID) {
        guard self.pill == pill, kind == .working, message != nil else { return }
        dismiss()
    }

    /// Runs `handler` once the toast of `pill` leaves (its time ran out, a tap, another toast in its place), or at once when it is
    /// already gone.
    func onLeave(of pill: UUID, _ handler: @escaping () -> Void) {
        guard message != nil, self.pill == pill else {
            handler()
            return
        }
        leaveHandlers[pill] = handler
    }

    /// How long a toast stays: what was asked for, else 4 s for one with a button, else the default.
    func duration(for requested: Duration?, hasAction: Bool) -> Duration {
        requested ?? (hasAction ? Self.actionDuration : defaultDuration)
    }

    func dismiss() {
        dismissTask?.cancel()
        tapTask?.cancel()
        let leaving = message == nil ? nil : pill
        message = nil
        kind = .done
        action = nil
        if let leaving { left(leaving) }
        if let next = waiting {
            waiting = nil
            show(next.message, kind: next.kind, duration: next.duration, action: next.action)
        }
    }

    /// The toast of `pill` is gone: whoever waited on it is told.
    private func left(_ pill: UUID) {
        leaveHandlers.removeValue(forKey: pill)?()
    }

    /// The tap that goes with the icon's gesture: success when work ends well, the warning with a "!", a light one with a "★".
    /// A plain ✓ has none (the creator's own tap already had one).
    private func tap(for kind: ToastKind, endsWork: Bool) {
        tapTask?.cancel()
        guard kind != .working, kind != .done || endsWork else { return }
        let delay = kind == .cue && !endsWork ? Self.cueTapDelay : Self.tapDelay
        tapTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            switch kind {
            case .problem: Haptics.warning()
            case .cue where !endsWork: Haptics.soft()
            case .done, .cue, .working: Haptics.success()
            }
        }
    }
}
