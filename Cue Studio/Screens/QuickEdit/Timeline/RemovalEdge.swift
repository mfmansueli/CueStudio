//
//  RemovalEdge.swift
//  Cue Studio
//

import Foundation

/// The two red edges of "Remove part": where the part to take out starts and ends.
nonisolated enum RemovalEdge: Equatable, Sendable {
    case start, end
}
