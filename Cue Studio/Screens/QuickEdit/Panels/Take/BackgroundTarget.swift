//
//  BackgroundTarget.swift
//  Cue Studio
//

import Foundation

/// Where a Background change goes: one clip's own background, or a recording's (nil: the take), on every section of it.
nonisolated enum BackgroundTarget: Equatable, Sendable {
    case clip(UUID)
    case recording(UUID?)
}
