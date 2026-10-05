//
//  SystemPasteboard.swift
//  Cue Studio
//

import UIKit

final class SystemPasteboard: PasteboardWriting {
    func setItems(_ items: [[String: Any]], expiresAt: Date) {
        UIPasteboard.general.setItems(items, options: [.expirationDate: expiresAt])
    }

    func clear() {
        UIPasteboard.general.items = []
    }
}
