//
//  DocumentImporting.swift
//  Cue Studio
//

import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// Turns files and the clipboard into script text.
protocol DocumentImporting: AnyObject {
    var supportedTypes: [UTType] { get }
    func importDocument(at url: URL) throws -> ImportedDocument
    /// Page images of a PDF without a text layer, so they can go through text recognition: at most `maxPages`, drawn off the
    /// main thread, with how many pages the file has.
    func pageImages(ofPDFAt url: URL, maxPages: Int) async -> ScannedPDFPages
    /// Text on the clipboard, normalized. Nil when there is none.
    func clipboardText() -> String?
}
