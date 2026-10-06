//
//  PhotosAccess.swift
//  Cue Studio
//

import Foundation

/// How far the creator let Cue into Photos: Cue only adds videos, so "Add only" is all it ever asks for.
nonisolated enum PhotosAccess: Equatable, Sendable {
    case notAsked, addOnly, full, denied
}
