//
//  SimulatedSceneCapture.swift
//  Cue Studio
//

#if DEBUG
import Foundation
import notify

/// UI tests: the scene counts as recorded or mirrored (`SceneCaptured`). `-uiTestSceneCapture on` starts captured and
/// `-uiTestSceneCapture off` starts clear; either way the test runner can then start and stop "capture" while the app runs, as
/// Control Center's Screen Recording would, by posting the Darwin notifications `onNotification` / `offNotification`
/// (`notify_post`). The Simulator's own recording never marks the scene as captured, so there is no other way to see it there.
/// Never shipped.
@MainActor
@Observable
final class SimulatedSceneCapture {
    static let shared = SimulatedSceneCapture()
    static let onNotification = "studio.cue.uitest.sceneCapture.on"
    static let offNotification = "studio.cue.uitest.sceneCapture.off"

    private(set) var isActive = false
    @ObservationIgnored private var tokens: [Int32] = []

    /// Reads `-uiTestSceneCapture` and, when it is there, starts listening for the test runner.
    func start(arguments: [String]) {
        guard tokens.isEmpty, let index = arguments.firstIndex(of: "-uiTestSceneCapture"), arguments.indices.contains(index + 1) else { return }
        isActive = arguments[index + 1] == "on"
        listen(Self.onNotification, active: true)
        listen(Self.offNotification, active: false)
    }

    private func listen(_ name: String, active: Bool) {
        var token: Int32 = 0
        // Delivered on the main queue, so the handler is already on the main actor.
        let status = notify_register_dispatch(name, &token, .main) { _ in
            MainActor.assumeIsolated { SimulatedSceneCapture.shared.isActive = active }
        }
        if status == UInt32(NOTIFY_STATUS_OK) { tokens.append(token) }
    }
}
#endif
