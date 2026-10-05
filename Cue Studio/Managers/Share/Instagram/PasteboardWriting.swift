//
//  PasteboardWriting.swift
//  Cue Studio
//

import Foundation

/// The system pasteboard, so tests can read what Cue put there.
protocol PasteboardWriting: AnyObject {
    func setItems(_ items: [[String: Any]], expiresAt: Date)
    /// Takes back what `setItems` put there (the composer didn't open, so nobody will read it).
    func clear()
}
