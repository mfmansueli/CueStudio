//
//  WatchSessionModel.swift
//  Cue Studio Watch
//

import Foundation
import Observation

/// The watch app's state: the iPhone's last answer, what was asked and not answered yet, and what lives only on the wrist
/// (End armed for 3 s, the crown on the speed, the page shown during a take). The screen comes from `WatchScreenRule`.
@MainActor
@Observable
final class WatchSessionModel {
    /// The two pages of a take: its time and End, and the text's controls.
    enum Page: Hashable {
        case recording
        case text
    }

    /// End is armed this long after the first tap; a second tap in it ends the take.
    static let armedFor: TimeInterval = 3

    private(set) var state: WatchPhoneState?
    private(set) var isReachable = false
    private(set) var pending: WatchCommand?
    private(set) var pendingSince: Date?
    /// "Done" on a saved take: the watch shows Ready until another take is saved.
    private(set) var leftSavedTake = false
    private(set) var armedUntil: Date?
    /// The Digital Crown turns the speed.
    var crownTurnsSpeed = false
    /// The crown's speed, as times the natural pace; follows the iPhone's while the crown isn't on it.
    var crownSpeed = 1.0
    var page = Page.recording
    /// Read again when a wait may have run out, so the screen moves on by itself.
    private(set) var now = Date.now

    @ObservationIgnored private let link: WatchSessionLink
    @ObservationIgnored private var speedTask: Task<Void, Never>?

    init(link: WatchSessionLink = WatchSessionLink()) {
        self.link = link
    }

    var screen: WatchScreen {
        WatchScreenRule.screen(
            state: state, isReachable: isReachable, pending: pending, pendingSince: pendingSince, now: now, leftSavedTake: leftSavedTake
        )
    }

    var isArmed: Bool { armedUntil.map { now < $0 } ?? false }

    func start() {
        link.onState = { [weak self] state in self?.receive(state) }
        link.onReachability = { [weak self] reachable in self?.reachabilityChanged(reachable) }
        link.activate()
        isReachable = link.isReachable
        // Nothing old is shown as current: the context's state is the "last state" of No connection until the iPhone answers.
        if let context = link.lastContext { state = context }
        refresh()
    }

    #if DEBUG
    /// A board state without an iPhone (`WatchDemo`): nothing is sent.
    func show(_ demo: WatchDemoSnapshot) {
        state = demo.state
        isReachable = demo.reachable
        pending = demo.pending.map { WatchCommand(action: $0) }
        pendingSince = demo.pending == nil ? nil : .now.addingTimeInterval(-demo.pendingFor)
        armedUntil = demo.armed ? .now.addingTimeInterval(3600) : nil
        crownTurnsSpeed = demo.crown
        crownSpeed = demo.state?.speedMultiple ?? 1
        page = demo.textPage ? .text : .recording
        now = .now
    }
    #endif

    /// Opening the app, raising the wrist, Try again: asks the iPhone where it is.
    func refresh() {
        isReachable = link.isReachable
        send(.refresh)
    }

    func send(_ action: WatchAction) {
        let before = screen
        let command = WatchCommand(action: action)
        if action == .done { leftSavedTake = true }
        if case .record = action { leftSavedTake = false }
        armedUntil = nil
        pending = command
        pendingSince = .now
        now = .now
        if !link.send(command) { isReachable = false }
        tick(after: WatchScreenRule.answerTimeout + 0.2)
        WatchHaptics.screenChanged(from: before, to: screen)
    }

    /// End: the first tap arms it for 3 s ("Tap again to end"); the second ends the take.
    func tapEnd() {
        if isArmed {
            send(.stop)
        } else {
            armedUntil = .now.addingTimeInterval(Self.armedFor)
            now = .now
            tick(after: Self.armedFor + 0.1)
        }
    }

    /// The crown moved the speed: the iPhone hears the last value a moment after it stops.
    func crownMoved() {
        speedTask?.cancel()
        let multiple = (crownSpeed * 10).rounded() / 10
        speedTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self?.send(.setSpeed(multiple: multiple))
        }
    }

    private func receive(_ new: WatchPhoneState) {
        // A state older than the one shown (the context arriving after a message) changes nothing.
        if let state, new.sentAt < state.sentAt { return }
        let before = screen
        if case .saved(let take, _) = new.phase, case .saved(let shown, _)? = state?.phase, take != shown { leftSavedTake = false }
        if case .recording = new.phase {} else { page = .recording }
        state = new
        isReachable = true
        if let pending, new.answering == pending.id {
            self.pending = nil
            pendingSince = nil
        }
        if !crownTurnsSpeed { crownSpeed = new.speedMultiple }
        now = .now
        WatchHaptics.screenChanged(from: before, to: screen)
    }

    private func reachabilityChanged(_ reachable: Bool) {
        let before = screen
        isReachable = reachable
        now = .now
        if reachable { send(.refresh) } else { WatchHaptics.screenChanged(from: before, to: screen) }
    }

    /// Looks at the time again after `seconds`: a wait that ran out, End no longer armed. Each look stands alone, so End's
    /// never cancels a command's.
    private func tick(after seconds: TimeInterval) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self else { return }
            let before = self.screen
            self.now = .now
            WatchHaptics.screenChanged(from: before, to: self.screen)
        }
    }
}
