//
//  DocumentImporting.swift
//  Cue Studio
//

import Foundation
import UniformTypeIdentifiers

/// Turns files and the clipboard into script text.
protocol DocumentImporting: AnyObject {
    var supportedTypes: [UTType] { get }
    func importDocument(at url: URL) throws -> ImportedDocument
    /// Text on the clipboard, normalized. Nil when there is none.
    func clipboardText() -> String?
}
