//
//  FakeVideoSharing.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// A device where every platform answers as a test says. It proves how Cue reacts to each answer, not that a platform
/// really delivers: that needs the apps on an iPhone.
@MainActor
final class FakeVideoSharing: VideoSharing {
    struct Sent: Equatable {
        let video: SharedVideo
        let destination: ShareDestination
        let route: ShareRoute
    }

    var routes: [ShareDestination: ShareRoute] = [:]
    var defaultRoute: ShareRoute = .saveAndOpen
    /// What `send` answers right away.
    var outcome: ShareOutcome = .opened
    private(set) var sent: [Sent] = []
    /// The callback of the last `send`, for a platform answering later.
    private(set) var finish: (@MainActor @Sendable (ShareOutcome) -> Void)?

    func route(for destination: ShareDestination, duration: TimeInterval) -> ShareRoute {
        routes[destination] ?? defaultRoute
    }

    func send(
        _ video: SharedVideo, to destination: ShareDestination, via route: ShareRoute,
        finished: @escaping @MainActor @Sendable (ShareOutcome) -> Void
    ) async -> ShareOutcome {
        sent.append(Sent(video: video, destination: destination, route: route))
        finish = finished
        return outcome
    }

    func handleCallback(_ url: URL) -> Bool { false }
}
