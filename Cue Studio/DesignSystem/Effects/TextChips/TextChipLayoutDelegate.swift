//
//  TextChipLayoutDelegate.swift
//  Cue Studio
//

import UIKit

/// What a TextKit 2 text view needs to show `TextChip`s: paragraphs with chips are laid out as `TextChipFragment`s (the rest as usual),
/// and a line never breaks inside a chip, so "[look at camera]" moves to the next line whole instead of splitting after "look".
/// The text view keeps it (its layout manager only holds its delegate weakly).
nonisolated final class TextChipLayoutDelegate: NSObject, NSTextLayoutManagerDelegate {
    func textLayoutManager(
        _ textLayoutManager: NSTextLayoutManager,
        textLayoutFragmentFor location: any NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        guard let paragraph = textElement as? NSTextParagraph, Self.hasChips(paragraph.attributedString) else {
            return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
        }
        return TextChipFragment(textElement: textElement, range: textElement.elementRange)
    }

    func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, shouldBreakLineBefore location: any NSTextLocation, hyphenating: Bool) -> Bool {
        guard let storage = (textLayoutManager.textContentManager as? NSTextContentStorage)?.textStorage else { return true }
        let offset = textLayoutManager.offset(from: textLayoutManager.documentRange.location, to: location)
        guard offset > 0, offset < storage.length else { return true }
        let before = storage.attribute(TextChipAttribute.nsKey, at: offset - 1, effectiveRange: nil) as? TextChipBox
        let after = storage.attribute(TextChipAttribute.nsKey, at: offset, effectiveRange: nil) as? TextChipBox
        return before == nil || before !== after
    }

    private static func hasChips(_ string: NSAttributedString) -> Bool {
        var found = false
        string.enumerateAttribute(TextChipAttribute.nsKey, in: NSRange(location: 0, length: string.length)) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}
