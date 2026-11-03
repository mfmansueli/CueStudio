//
//  ParagraphGauge.swift
//  Cue Studio
//

import UIKit

/// How tall one paragraph of the script is, laid out on its own by TextKit 2 in a container as wide as the editor's (`ScriptTextView`):
/// the same engine, width and cue chips, so it wraps where the editor does, and the editor's own layout is neither touched nor trusted.
/// Typing changes one paragraph, so while the creator types in it the editor's height is the whole script as measured when the typing in
/// that paragraph began, plus what the paragraph grew by since (03/11/2026: the editor's layout leaves the paragraphs under an edit where
/// they were until they are drawn, so its bounds fell two lines short at the end of an 800-word script, and laying the whole script out
/// for each of SwiftUI's measures was what made typing in a long one lag). The last answer is kept: SwiftUI asks several times a letter.
@MainActor
final class ParagraphGauge {
    private let content = NSTextContentStorage()
    private let layout = NSTextLayoutManager()
    private let container = NSTextContainer(size: .zero)
    private var kept: (paragraph: String, width: CGFloat, height: CGFloat)?

    init(lineFragmentPadding: CGFloat, chips: NSTextLayoutManagerDelegate) {
        container.lineFragmentPadding = lineFragmentPadding
        layout.textContainer = container
        layout.delegate = chips
        content.addTextLayoutManager(layout)
    }

    /// The paragraph's height in a text container `width` wide.
    func height(of paragraph: NSAttributedString, width: CGFloat) -> CGFloat {
        if let kept, kept.width == width, kept.paragraph == paragraph.string { return kept.height }
        container.size = CGSize(width: width, height: 10_000_000)
        content.attributedString = paragraph
        layout.ensureLayout(for: layout.documentRange)
        var bottom: CGFloat = 0
        let options: NSTextLayoutFragment.EnumerationOptions = [.reverse, .ensuresLayout, .ensuresExtraLineFragment]
        layout.enumerateTextLayoutFragments(from: layout.documentRange.endLocation, options: options) { fragment in
            bottom = fragment.layoutFragmentFrame.maxY
            return false
        }
        let height = max(bottom, layout.usageBoundsForTextContainer.maxY)
        kept = (paragraph.string, width, height)
        return height
    }
}
