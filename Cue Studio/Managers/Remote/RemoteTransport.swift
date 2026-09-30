//
//  RemoteTransport.swift
//  Cue Studio
//

import Foundation

/// The link between the teleprompter and the device that controls it: the Network framework in the
/// app, a fake in tests. Other controllers (keyboard, foot pedal, Bluetooth remote) won't need a
/// transport: they only produce `RemoteCommand`s for the prompter.
protocol RemoteTransport: AnyObject {
    /// Called on the main actor.
    var onEvent: ((RemoteTransportEvent) -> Void)? { get set }
    /// Teleprompter: waits for the device that has `code`.
    func host(code: String)
    /// Remote: looks for the teleprompter showing `code`.
    func join(code: String)
    func send(_ message: RemoteMessage)
    func stop()
}
