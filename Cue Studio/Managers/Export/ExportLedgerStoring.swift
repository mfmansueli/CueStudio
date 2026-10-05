//
//  ExportLedgerStoring.swift
//  Cue Studio
//

import Foundation

/// Where the export operations are kept between launches, so an interruption or a restored app never counts the same
/// export twice.
protocol ExportLedgerStoring: AnyObject {
    func load() -> [ExportOperation]
    func save(_ operations: [ExportOperation])
}
