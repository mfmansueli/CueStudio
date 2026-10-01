//
//  PaddedLabel.swift
//  Cue Studio
//

import UIKit

/// A label with room around its text: the timeline's time bubble.
final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
