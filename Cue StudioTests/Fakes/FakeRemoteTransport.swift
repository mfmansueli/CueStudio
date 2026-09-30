//
//  FakeRemoteTransport.swift
//  Cue StudioTests
//

@testable import Cue_Studio

@MainActor
final class FakeRemoteTransport: RemoteTransport {
    var onEvent: ((RemoteTransportEvent) -> Void)?
    private(set) var hostedCodes: [String] = []
    private(set) var joinedCodes: [String] = []
    private(set) var sent: [RemoteMessage] = []
    private(set) var stopCount = 0

    func host(code: String) {
        hostedCodes.append(code)
    }

    func join(code: String) {
        joinedCodes.append(code)
    }

    func send(_ message: RemoteMessage) {
        sent.append(message)
    }

    func stop() {
        stopCount += 1
    }

    /// What the other device (or the network) would report.
    func emit(_ event: RemoteTransportEvent) {
        onEvent?(event)
    }

    var sentStatuses: [RemoteStatus] {
        sent.compactMap { message in
            if case .status(let status) = message { return status }
            return nil
        }
    }

    var sentCommands: [RemoteCommand] {
        sent.compactMap { message in
            if case .command(let command) = message { return command }
            return nil
        }
    }
}
