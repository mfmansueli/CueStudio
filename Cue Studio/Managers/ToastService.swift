//
//  ToastService.swift
//  Cue Studio
//

import SwiftUI

/// Short confirmations shown at the top of whatever screen is in front, one at a time, each with its kind (`ToastKind`).
@MainActor
@Observable
final class ToastService {
    private(set) var message: String?
    private(set) var kind: ToastKind = .done
    /// The button beside the message, when the toast has one.
    private(set) var action: ToastAction?
    /// The pill on screen: a new one for every toast, except the toast that ends work under way, which takes the working
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
    private var dismissTask: Task<Void, Never>?
    private var tapTask: Task<Void, Never>?

    func show(_ message: String, kind: ToastKind = .done, duration: Duration? = nil, action: ToastAction? = nil) {
        let endsWork = self.message != nil && self.kind == .working && kind != .working
        if !endsWork { pill = UUID() }
        let duration = kind == .working ? Self.workingLimit : self.duration(for: duration, hasAction: action != nil)
        dismissTask?.cancel()
        self.message = message
        self.kind = kind
        self.action = action
        AccessibilityNotification.Announcement(message).post()
        tap(for: kind, endsWork: endsWork)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    /// Work under way ("Freezing the frame…"), with the turning ring. The next toast (what came of it) takes its place in the same
    /// pill; when the work ends with nothing to say, `endWorking` with the pill returned lets it go.
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

    /// How long a toast stays: what was asked for, else 4 s for one with a button, else the default.
    func duration(for requested: Duration?, hasAction: Bool) -> Duration {
        requested ?? (hasAction ? Self.actionDuration : defaultDuration)
    }

    func dismiss() {
        dismissTask?.cancel()
        tapTask?.cancel()
        message = nil
        kind = .done
        action = nil
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
