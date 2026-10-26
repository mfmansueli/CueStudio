//
//  EditorToolbarBadge.swift
//  Cue Studio
//

import UIKit

/// The words of a tool's scope badge (`EditorToolbarItem.ScopeBadge`), in capitals: the long ones ("WHOLE VIDEO" in English)
/// when they fit the bar (`EditorToolbarFit.longBadgeFits`), else the short one ("ALL"). The badge is drawn at a fixed size, so
/// what is measured here is what shows.
enum EditorToolbarBadge {
    static let font = UIFont.systemFont(ofSize: EditorGlyph.badge, weight: .heavy)

    /// The long words of `badge` in the app's language, and the short ones.
    static func long(_ badge: EditorToolbarItem.ScopeBadge) -> String { badge.label.uppercased(with: .current) }
    static func short(_ badge: EditorToolbarItem.ScopeBadge) -> String { badge.shortLabel.uppercased(with: .current) }

    /// How wide `words` are drawn in the badge.
    static func width(of words: String) -> CGFloat {
        ceil((words as NSString).size(withAttributes: [.font: font]).width)
    }
}
