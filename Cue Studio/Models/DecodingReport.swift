//
//  DecodingReport.swift
//  Cue Studio
//

import Foundation
import os

/// What reading a saved file had to leave out or read another way: a list element that couldn't be read (`LossyList`), a
/// choice a newer version of Cue wrote (`LenientChoice`), an edit that couldn't be read (`Take`). The store reading the file
/// sets one on its decoder (`JSONDecoder.reporting(to:)`) and, when anything was noted, logs it and keeps the file as it was
/// before it is saved again without it.
nonisolated final class DecodingReport: Sendable {
    private let state = OSAllocatedUnfairLock<[String]>(initialState: [])

    /// What was left out or read another way, in the order it happened: type names and values, never the creator's text.
    var notes: [String] { state.withLock { $0 } }

    func note(_ note: String) {
        state.withLock { $0.append(note) }
    }
}

extension CodingUserInfoKey {
    nonisolated static let decodingReport = CodingUserInfoKey(rawValue: "studio.cue.decodingReport")!
}

extension Decoder {
    /// The report the store reading this file asked for; nil when it didn't.
    nonisolated var decodingReport: DecodingReport? {
        userInfo[.decodingReport] as? DecodingReport
    }
}

extension JSONDecoder {
    /// This decoder, with what its readers leave out noted in `report`.
    nonisolated func reporting(to report: DecodingReport) -> JSONDecoder {
        userInfo[.decodingReport] = report
        return self
    }
}
