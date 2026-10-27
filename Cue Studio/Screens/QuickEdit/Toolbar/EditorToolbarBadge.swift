//
//  EditorToolbarBadge.swift
//  Cue Studio
//

import UIKit

/// The words of a tool's scope badge (`EditorToolbarItem.ScopeBadge`): the short "ALL" ("TODOS" in Portuguese), in capitals, at the
/// icon's corner. The badge is drawn at a fixed size, so what is measured here is what shows.
enum EditorToolbarBadge {
    static let font = UIFont.systemFont(ofSize: EditorGlyph.badge, weight: .heavy)

    /// The badge's words in the app's language.
    static func words(_ badge: EditorToolbarItem.ScopeBadge) -> String { badge.label.uppercased(with: .current) }

    /// How wide `words` are drawn in the badge.
    static func width(of words: String) -> CGFloat {
        ceil((words as NSString).size(withAttributes: [.font: font]).width)
    }
}
