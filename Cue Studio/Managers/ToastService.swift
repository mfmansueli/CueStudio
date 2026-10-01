//
//  ToastService.swift
//  Cue Studio
//

import SwiftUI

/// Short confirmations shown at the top of whatever screen is in front.
@MainActor
@Observable
final class ToastService {
    private(set) var message: String?
    /// How long a toast stays when none is given: the editor's last 2 s.
    var defaultDuration: Duration = .seconds(2.4)
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, duration: Duration? = nil) {
        let duration = duration ?? defaultDuration
        dismissTask?.cancel()
        self.message = message
        AccessibilityNotification.Announcement(message).post()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        message = nil
    }
}
