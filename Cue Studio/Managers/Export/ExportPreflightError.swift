//
//  ExportPreflightError.swift
//  Cue Studio
//

import Foundation

/// Why an export doesn't start: told before any work, never after minutes of it.
nonisolated enum ExportPreflightError: Error, Equatable {
    /// About this many megabytes have to be freed (`StorageSpace`).
    case notEnoughSpace(megabytes: Int)
}
