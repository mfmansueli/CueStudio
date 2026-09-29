//
//  DemoRemoteTransport.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// A remote link for previews and UI tests, which have no second device (and must not trigger the
/// Local Network prompt). With `connects`, an iPad "joins" a moment after pairing starts and plays
/// along with what the teleprompter reports.
final class DemoRemoteTransport: RemoteTransport {
    var onEvent: ((RemoteTransportEvent) -> Void)?

    private let connects: Bool
    private var task: Task<Void, Never>?

    init(connects: Bool) {
        self.connects = connects
    }

    func host(code: String) {
        connectSoon()
    }

    func join(code: String) {
        connectSoon()
    }

    func send(_ message: RemoteMessage) {}

    func stop() {
        task?.cancel()
        task = nil
    }

    private func connectSoon() {
        guard connects else { return }
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.onEvent?(.connected(deviceName: String(localized: "iPad")))
        }
    }
}
#endif
