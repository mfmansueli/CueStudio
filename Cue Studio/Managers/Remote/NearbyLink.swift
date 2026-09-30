//
//  NearbyLink.swift
//  Cue Studio
//

import Foundation
import Network

/// One link between the teleprompter and a remote over the Network framework: the local network,
/// or peer to peer over Wi-Fi when the two devices share no network. The teleprompter advertises a
/// Bonjour service named after its pairing code (`RemoteCipher.serviceName`); the remote finds
/// that name and connects. Every frame is sealed with a key derived from the code, and a remote is
/// let in only once it answers the teleprompter's challenge, so only the device that has the code
/// gets in. One remote at a time; the remote reconnects on its own when it comes back in range.
///
/// The Network framework calls its handlers on `queue`, where all the state lives, so it is
/// `@unchecked Sendable`: nothing is read or changed anywhere else.
nonisolated final class NearbyLink: @unchecked Sendable {
    /// Also listed under NSBonjourServices in Info.plist.
    static let serviceType = "_cue-remote._tcp"
    /// `kDNSServiceErr_PolicyDenied`: Local Network is off for Cue.
    private static let localNetworkDenied: Int32 = -65_570

    private nonisolated enum Frame: Codable {
        /// Teleprompter → remote first, with a fresh challenge; the remote answers with its own
        /// name and the same challenge.
        case hello(name: String, challenge: Data)
        case message(RemoteMessage)
    }

    private let hosting: Bool
    private let cipher: RemoteCipher
    private let deviceName: String
    private let onEvent: @Sendable (RemoteTransportEvent) -> Void
    private let queue = DispatchQueue(label: "studio.cue.remote")

    private var listener: NWListener?
    private var browser: NWBrowser?
    /// The connection that answered the challenge (teleprompter) or that was accepted (remote).
    private var active: NWConnection?
    /// Teleprompter: connections that haven't answered yet, with the challenge each was sent.
    private var pending: [ObjectIdentifier: (connection: NWConnection, challenge: Data)] = [:]
    /// Remote: the connection being set up, before the teleprompter says hello.
    private var joining: NWConnection?
    private var isStopped = false

    /// `hosting`: the teleprompter side. Otherwise the remote.
    init(hosting: Bool, code: String, deviceName: String, onEvent: @escaping @Sendable (RemoteTransportEvent) -> Void) {
        self.hosting = hosting
        cipher = RemoteCipher(code: code)
        self.deviceName = deviceName
        self.onEvent = onEvent
    }

    func start() {
        queue.async { [self] in
            if hosting { listen() } else { browse() }
        }
    }

    func stop() {
        queue.async { [self] in
            isStopped = true
            listener?.cancel()
            browser?.cancel()
            active?.cancel()
            joining?.cancel()
            pending.values.forEach { $0.connection.cancel() }
            pending.removeAll()
        }
    }

    func send(_ message: RemoteMessage) {
        queue.async { [self] in
            guard let active else { return }
            send(.message(message), on: active)
        }
    }

    // MARK: - Teleprompter

    private func listen() {
        let listener: NWListener
        do {
            listener = try NWListener(using: Self.parameters())
        } catch {
            onEvent(.failed(Self.localNetworkMessage))
            return
        }
        listener.service = NWListener.Service(name: cipher.serviceName, type: Self.serviceType)
        listener.stateUpdateHandler = { [weak self] state in
            self?.listenerChanged(state)
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    private func listenerChanged(_ state: NWListener.State) {
        switch state {
        case .failed:
            onEvent(.failed(Self.localNetworkMessage))
        case .waiting(let error) where Self.isLocalNetworkDenied(error):
            onEvent(.failed(Self.localNetworkMessage))
        default:
            break
        }
    }

    /// Anyone nearby can open a connection; only the one that answers the challenge stays.
    private func accept(_ connection: NWConnection) {
        guard !isStopped, active == nil else {
            connection.cancel()
            return
        }
        let challenge = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        pending[ObjectIdentifier(connection)] = (connection, challenge)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                send(.hello(name: deviceName, challenge: challenge), on: connection)
            case .failed, .cancelled:
                dropped(connection)
            default:
                break
            }
        }
        receive(on: connection)
        connection.start(queue: queue)
    }

    private func dropped(_ connection: NWConnection) {
        pending[ObjectIdentifier(connection)] = nil
        guard connection === active else { return }
        active = nil
        if !isStopped { onEvent(.disconnected) }
    }

    // MARK: - Remote

    private func browse() {
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: Self.parameters())
        browser.stateUpdateHandler = { [weak self] state in
            self?.browserChanged(state)
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.connectIfFound(in: results)
        }
        self.browser = browser
        browser.start(queue: queue)
    }

    private func browserChanged(_ state: NWBrowser.State) {
        switch state {
        case .failed:
            onEvent(.failed(Self.localNetworkMessage))
        case .waiting(let error) where Self.isLocalNetworkDenied(error):
            onEvent(.failed(Self.localNetworkMessage))
        default:
            break
        }
    }

    private func connectIfFound(in results: Set<NWBrowser.Result>) {
        guard !isStopped, active == nil, joining == nil else { return }
        let teleprompter = results.first { result in
            if case .service(let name, _, _, _) = result.endpoint { name == cipher.serviceName } else { false }
        }
        guard let teleprompter else { return }
        let connection = NWConnection(to: teleprompter.endpoint, using: Self.parameters())
        joining = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .failed, .cancelled:
                lost(connection)
            default:
                break
            }
        }
        receive(on: connection)
        connection.start(queue: queue)
    }

    /// Keeps looking, so the remote reconnects on its own when it comes back in range.
    private func lost(_ connection: NWConnection) {
        if connection === joining { joining = nil }
        if connection === active {
            active = nil
            if !isStopped { onEvent(.disconnected) }
        }
        queue.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, let results = browser?.browseResults else { return }
            connectIfFound(in: results)
        }
    }

    // MARK: - Frames

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let self, let connection else { return }
            if let data, !data.isEmpty {
                handle(data, from: connection)
            }
            if error == nil { receive(on: connection) }
        }
    }

    private func handle(_ sealed: Data, from connection: NWConnection) {
        guard let plain = try? cipher.open(sealed), let frame = try? JSONDecoder().decode(Frame.self, from: plain) else {
            // Not sealed with this code.
            connection.cancel()
            return
        }
        switch frame {
        case .message(let message):
            if connection === active { onEvent(.received(message)) }
        case .hello(let name, let challenge):
            if hosting {
                answered(connection, name: name, challenge: challenge)
            } else if connection === joining {
                joining = nil
                active = connection
                send(.hello(name: deviceName, challenge: challenge), on: connection)
                onEvent(.connected(deviceName: name))
            }
        }
    }

    /// Teleprompter: the remote sent the challenge back, so it has the code.
    private func answered(_ connection: NWConnection, name: String, challenge: Data) {
        guard let sent = pending.removeValue(forKey: ObjectIdentifier(connection)),
              sent.challenge == challenge, active == nil
        else {
            connection.cancel()
            return
        }
        active = connection
        onEvent(.connected(deviceName: name))
    }

    private func send(_ frame: Frame, on connection: NWConnection) {
        guard let plain = try? JSONEncoder().encode(frame), let sealed = try? cipher.seal(plain) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "frame", metadata: [metadata])
        connection.send(content: sealed, contentContext: context, isComplete: true, completion: .idempotent)
    }

    // MARK: - Setup

    /// TCP with WebSocket messages on top (each frame arrives whole), peer to peer allowed.
    private static func parameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let webSocket = NWProtocolWebSocket.Options()
        webSocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
        return parameters
    }

    private static func isLocalNetworkDenied(_ error: NWError) -> Bool {
        if case .dns(let code) = error { code == localNetworkDenied } else { false }
    }

    private static var localNetworkMessage: String {
        String(localized: "Cue can't reach nearby devices. Turn on Local Network for Cue in Settings.")
    }
}
