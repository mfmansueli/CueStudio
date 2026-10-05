//
//  ShareOutcome.swift
//  Cue Studio
//

import Foundation

/// What came of handing a video to a destination.
nonisolated enum ShareOutcome: Equatable, Sendable {
    /// Evidence that the video left Cue and reached the destination (never that it was published).
    case delivered(DeliveryEvidence)
    /// The platform was sent the request and will report back (Share Kit); nothing is known yet.
    case pending
    /// The app was opened, but nothing says the video arrived: the creator picks it there, or the platform has no
    /// callback. This never counts as a delivery.
    case opened
    /// The creator backed out before the video was delivered.
    case cancelled
    /// The destination can't be used right now; the video goes through another route.
    case unavailable(ShareUnavailability)
    case failed(ShareFailure)
}

nonisolated enum ShareUnavailability: Equatable, Sendable {
    case appNotInstalled
    /// The app is there but wouldn't open.
    case couldNotOpen
}

nonisolated enum ShareFailure: Equatable, Sendable {
    /// The destination's app couldn't read the video from Photos.
    case photosAccess
    /// The platform refused the video (length, size, format) or the request.
    case rejected
    case unknown
}
