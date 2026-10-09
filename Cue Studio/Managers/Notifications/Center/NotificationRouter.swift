//
//  NotificationRouter.swift
//  Cue Studio
//

import Foundation

/// Hands notification taps to the UI. A tap can arrive before the first screen exists (a cold launch from a notification), during the
/// first flight, or while the creator is at the camera, so it waits here until `RootView` is ready to take it (`NotificationService.open`).
/// Each delivered notification is queued once, however many times the system calls back. A singleton by necessity (ARCHITECTURE.md 2.2),
/// like `IntentRouter`: the system's delegate lives outside the SwiftUI tree.
@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    private(set) var pending: [NotificationInteraction] = []
    /// How a notification shows while Cue is on screen; set by `NotificationService` once it exists. Before that, as usual.
    @ObservationIgnored var foreground: ((NotificationPayload?, String) -> ForegroundPresentation)?

    func receive(_ interaction: NotificationInteraction) {
        guard !pending.contains(where: { $0.id == interaction.id }) else { return }
        pending.append(interaction)
    }

    /// The oldest tap waiting, removed so it runs once.
    func take() -> NotificationInteraction? {
        pending.isEmpty ? nil : pending.removeFirst()
    }

    func presentation(payloadText: String?, requestID: String) -> ForegroundPresentation {
        foreground?(NotificationPayload.decode(payloadText), requestID) ?? .banner
    }
}
