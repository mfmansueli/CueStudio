//
//  WatchMessage.swift
//  Cue Studio
//

import Foundation

/// How commands and states travel through WatchConnectivity: JSON under one key of the dictionaries it carries.
nonisolated enum WatchMessage {
    static let commandKey = "command"
    static let stateKey = "state"

    static func encode(_ command: WatchCommand) -> [String: Any] {
        [commandKey: (try? JSONEncoder().encode(command)) ?? Data()]
    }

    static func encode(_ state: WatchPhoneState) -> [String: Any] {
        [stateKey: (try? JSONEncoder().encode(state)) ?? Data()]
    }

    static func command(in message: [String: Any]) -> WatchCommand? {
        (message[commandKey] as? Data).flatMap { try? JSONDecoder().decode(WatchCommand.self, from: $0) }
    }

    static func state(in message: [String: Any]) -> WatchPhoneState? {
        (message[stateKey] as? Data).flatMap { try? JSONDecoder().decode(WatchPhoneState.self, from: $0) }
    }
}
