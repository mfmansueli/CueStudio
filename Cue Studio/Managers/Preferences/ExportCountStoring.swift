//
//  ExportCountStoring.swift
//  Cue Studio
//

import Foundation

/// Where the number of free exports used is kept.
protocol ExportCountStoring: AnyObject {
    func load() -> Int
    func save(_ count: Int)
}
