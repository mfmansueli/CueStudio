//
//  InMemoryWatchTransport.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// No watch: previews and UI tests never touch WatchConnectivity. Keeps what was sent, for tests.
final class InMemoryWatchTransport: WatchTransport {
    var onCommand: ((WatchCommand) -> WatchPhoneState)?
    private(set) var sent: [WatchPhoneState] = []

    func activate() {}

    func send(_ state: WatchPhoneState) {
        sent.append(state)
    }

    /// A command as the watch would send it; the answer it got.
    func receive(_ action: WatchAction) -> WatchPhoneState? {
        onCommand?(WatchCommand(action: action))
    }
}
#endif
