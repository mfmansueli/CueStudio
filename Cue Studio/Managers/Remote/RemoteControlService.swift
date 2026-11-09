//
//  RemoteControlService.swift
//  Cue Studio
//

import Accessibility
import Foundation

/// Control the teleprompter from another device. The same app on both ends: the teleprompter shows
/// a QR code (`startHosting`), the other iPhone or iPad scans it and becomes the remote (`join`).
/// Lives for the app session, so a remote paired in Settings › Creator Setup is still there when
/// the prompter opens, and the prompter can pair one without leaving the recording.
@MainActor
@Observable
final class RemoteControlService {
    enum Role {
        /// This device runs the teleprompter.
        case teleprompter
        /// This device is the remote.
        case remote
    }

    /// While this device is the teleprompter (waiting for the remote or connected to it), its screen stays on: locking would drop the link.
    private(set) var role: Role? {
        didSet {
            guard role != oldValue else { return }
            if role == .teleprompter { screenAwake.hold(Self.awakeOwner) } else { screenAwake.release(Self.awakeOwner) }
        }
    }
    private static let awakeOwner = "remoteHost"
    private let screenAwake: ScreenAwake
    private(set) var state: RemoteConnectionState = .off
    /// The pairing code in use.
    private(set) var code: String?
    /// On the remote: what the teleprompter last reported.
    private(set) var teleprompterStatus: RemoteStatus?

    /// The prompter, while it's open: where commands go and what it reports.
    @ObservationIgnored private var commandHandler: ((RemoteCommand) -> Void)?
    @ObservationIgnored private var statusProvider: (() -> RemoteStatus)?

    private let transport: RemoteTransport
    private let makeCode: () -> String

    init(
        transport: RemoteTransport, makeCode: @escaping () -> String = { RemotePairing.makeCode() }, screenAwake: ScreenAwake = .shared
    ) {
        self.transport = transport
        self.screenAwake = screenAwake
        self.makeCode = makeCode
        transport.onEvent = { [weak self] event in self?.handle(event) }
    }

    var isConnected: Bool { state.isConnected }

    /// What the QR code holds.
    var pairingURL: URL? { code.flatMap(RemotePairing.url(for:)) }

    // MARK: - Teleprompter

    /// "Connect a Device": a new code, and waiting for the device that scans it.
    func startHosting() {
        transport.stop()
        let code = makeCode()
        self.code = code
        role = .teleprompter
        state = .waiting
        teleprompterStatus = nil
        transport.host(code: code)
    }

    /// The prompter opened: commands go to it from now on.
    func attach(onCommand: @escaping (RemoteCommand) -> Void, status: @escaping () -> RemoteStatus) {
        commandHandler = onCommand
        statusProvider = status
        publish(status())
    }

    /// The prompter closed: the remote shows that nothing is open.
    func detach() {
        commandHandler = nil
        statusProvider = nil
        publish(.idle)
    }

    /// Tells the remote what the teleprompter is doing.
    func publish(_ status: RemoteStatus) {
        guard role == .teleprompter, isConnected else { return }
        transport.send(.status(status))
    }

    // MARK: - Remote

    /// Becomes the remote of the teleprompter showing `code` (scanned or typed). False when the
    /// code can't be one.
    @discardableResult
    func join(code text: String) -> Bool {
        guard let code = RemotePairing.code(from: text) else { return false }
        transport.stop()
        self.code = code
        role = .remote
        state = .searching
        teleprompterStatus = nil
        transport.join(code: code)
        return true
    }

    func send(_ command: RemoteCommand) {
        guard role == .remote, isConnected else { return }
        transport.send(.command(command))
    }

    // MARK: - Both

    /// Disconnect: the link ends at once. The screen shows it; VoiceOver hears it, with no toast.
    func disconnect() {
        let wasConnected = state != .off
        transport.stop()
        role = nil
        code = nil
        state = .off
        teleprompterStatus = nil
        if wasConnected { AccessibilityNotification.Announcement(String(localized: "Remote disconnected")).post() }
    }

    private func handle(_ event: RemoteTransportEvent) {
        guard let role else { return }
        switch event {
        case .connected(let deviceName):
            state = .connected(deviceName: deviceName)
            if role == .teleprompter { publish(statusProvider?() ?? .idle) }
        case .disconnected:
            state = role == .teleprompter ? .waiting : .searching
            teleprompterStatus = nil
        case .received(.command(let command)):
            guard role == .teleprompter else { return }
            if let commandHandler {
                commandHandler(command)
            } else {
                publish(.idle)
            }
        case .received(.status(let status)):
            guard role == .remote else { return }
            teleprompterStatus = status
        case .failed(let message):
            state = .failed(message)
        }
    }
}
