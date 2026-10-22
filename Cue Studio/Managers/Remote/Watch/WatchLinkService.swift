//
//  WatchLinkService.swift
//  Cue Studio
//

import Foundation

/// The Apple Watch companion, on the iPhone's side. Lives for the app session: the recorder attaches while it is open
/// (`PrompterViewModel+Watch`), takes the watch's commands and tells it every change; with the recorder closed the watch
/// hears that there is nothing to record ("Prepare on your iPhone").
@MainActor
@Observable
final class WatchLinkService {
    /// The state the watch was last told.
    private(set) var lastState = WatchPhoneState.noSession

    @ObservationIgnored private var commandHandler: ((WatchCommand) -> Void)?
    @ObservationIgnored private var stateProvider: (() -> WatchPhoneState)?
    private let transport: WatchTransport

    init(transport: WatchTransport) {
        self.transport = transport
        transport.onCommand = { [weak self] command in self?.receive(command) ?? .noSession }
    }

    /// Starts listening for the watch (once, at launch).
    func activate() {
        transport.activate()
        publish(.noSession)
    }

    /// The recorder opened: commands go to it, and it tells its state.
    func attach(onCommand: @escaping (WatchCommand) -> Void, state: @escaping () -> WatchPhoneState) {
        commandHandler = onCommand
        stateProvider = state
        publish(state())
    }

    /// The recorder closed.
    func detach() {
        commandHandler = nil
        stateProvider = nil
        publish(.noSession)
    }

    /// The recorder's state changed.
    func publish(_ state: WatchPhoneState) {
        var sent = state
        sent.sentAt = .now
        lastState = sent
        transport.send(sent)
    }

    /// The recorder's current state, told again (after a change it can't see coming, such as a countdown's second).
    func publishCurrent() {
        guard let stateProvider else { return }
        publish(stateProvider())
    }

    /// A command: handled by the recorder when it is open, and answered with its state at once. The recorder names the
    /// command in its state (`answering`) when what it asked for has happened (a countdown started, a take saved, or why
    /// not), so the watch waits until then; with the recorder closed it is answered as done.
    private func receive(_ command: WatchCommand) -> WatchPhoneState {
        var answer: WatchPhoneState
        if let commandHandler, let stateProvider {
            commandHandler(command)
            answer = stateProvider()
        } else {
            answer = .noSession
            answer.answering = command.id
        }
        answer.sentAt = .now
        lastState = answer
        return answer
    }
}
