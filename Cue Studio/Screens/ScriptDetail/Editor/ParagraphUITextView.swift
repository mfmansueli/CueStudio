//
//  ParagraphUITextView.swift
//  Cue Studio
//

import UIKit

/// The text view of one paragraph. It knows the two things a plain one hides: Backspace pressed
/// with the caret at the very start (the paragraph joins the one before), and, with a hardware
/// keyboard, the arrows at the first and last line (the caret moves to the neighbor paragraph). It
/// also keeps the caret on screen: the paragraphs sit in a scroll view of their own, which the
/// text view can't see.
final class ParagraphUITextView: UITextView {
    var onBackspaceAtStart: (() -> Void)?
    var onArrowUpAtStart: (() -> Void)?
    var onArrowDownAtEnd: (() -> Void)?

    private var caretIsAtStart: Bool { selectedRange.location == 0 && selectedRange.length == 0 }
    private var caretIsAtEnd: Bool { selectedRange.location == (text as NSString).length && selectedRange.length == 0 }

    override func deleteBackward() {
        if caretIsAtStart, let onBackspaceAtStart {
            onBackspaceAtStart()
            return
        }
        super.deleteBackward()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let code = presses.first?.key?.keyCode
        if code == .keyboardUpArrow, caretIsAtStart, let onArrowUpAtStart {
            onArrowUpAtStart()
            return
        }
        if code == .keyboardDownArrow, caretIsAtEnd, let onArrowDownAtEnd {
            onArrowDownAtEnd()
            return
        }
        super.pressesBegan(presses, with: event)
    }

    /// Scrolls the enclosing scroll view so the caret, and a line around it, show.
    func scrollCaretIntoView() {
        guard isFirstResponder, let range = selectedTextRange else { return }
        let rect = caretRect(for: range.end)
        guard !rect.isNull, !rect.isInfinite, let scrollView = enclosingScrollView else { return }
        let margin = rect.height
        scrollView.scrollRectToVisible(convert(rect.insetBy(dx: 0, dy: -margin), to: scrollView), animated: false)
    }

    private var enclosingScrollView: UIScrollView? {
        var view = superview
        while let current = view {
            if let scrollView = current as? UIScrollView { return scrollView }
            view = current.superview
        }
        return nil
    }
}
