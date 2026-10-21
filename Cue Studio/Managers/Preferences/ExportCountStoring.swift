//
//  ExportCountStoring.swift
//  Cue Studio
//

import Foundation

/// Where the number of free exports used is kept.
protocol ExportCountStoring: AnyObject {
    /// Nil when the count couldn't be read (the Keychain before the first unlock): not the same as none used.
    func load() -> Int?
    func save(_ count: Int)
}
