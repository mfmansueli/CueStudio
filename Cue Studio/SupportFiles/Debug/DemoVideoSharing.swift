//
//  DemoVideoSharing.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// `-uiTestAppsInstalled`: every platform's app counts as installed and takes the video, so the send-off can be seen in a
/// Simulator that has none of them. A stand-in for UI tests only: it proves nothing about a real delivery (that needs the
/// apps on an iPhone, see `SHARING.md`).
final class DemoVideoSharing: VideoSharing {
    func route(for destination: ShareDestination, duration: TimeInterval) -> ShareRoute {
        .saveAndOpen
    }

    func send(
        _ video: SharedVideo, to destination: ShareDestination, via route: ShareRoute,
        finished: @escaping @MainActor @Sendable (ShareOutcome) -> Void
    ) async -> ShareOutcome {
        .delivered(.activity(type: "studio.cue.uitest"))
    }

    func handleCallback(_ url: URL) -> Bool { false }
}
#endif
