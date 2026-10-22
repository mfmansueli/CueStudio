//
//  ShareFailure.swift
//  Cue Studio
//

import Foundation

nonisolated enum ShareFailure: Equatable, Sendable {
    /// The destination's app couldn't read the video from Photos.
    case photosAccess
    /// The platform refused the video (length, size, format) or the request.
    case rejected
    case unknown
}
