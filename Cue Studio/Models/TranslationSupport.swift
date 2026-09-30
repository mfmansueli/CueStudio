//
//  TranslationSupport.swift
//  Cue Studio
//

import Foundation

/// Whether this iPhone can translate from one language to another, on the device.
nonisolated enum TranslationSupport: Equatable, Sendable {
    /// Ready now.
    case installed
    /// The system downloads the languages first (it asks).
    case downloadable
    /// Not this pair, on this iPhone.
    case unsupported
}
