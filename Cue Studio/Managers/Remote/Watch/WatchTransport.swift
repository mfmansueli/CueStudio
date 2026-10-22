//
//  WatchTransport.swift
//  Cue Studio
//

import Foundation

/// How the iPhone hears the watch and answers it (`WatchConnectivityTransport`; a fake in tests).
@MainActor
protocol WatchTransport: AnyObject {
    /// A command from the watch; what the handler returns goes back as its answer.
    var onCommand: ((WatchCommand) -> WatchPhoneState)? { get set }
    func activate()
    /// Tells the watch the recorder's state: at once when it is in reach, and as the latest state it reads when it opens.
    func send(_ state: WatchPhoneState)
}
