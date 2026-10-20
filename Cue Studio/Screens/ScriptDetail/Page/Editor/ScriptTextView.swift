//
//  ScriptTextView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The script page's text view: a TextKit 2 `UITextView` that draws its cues as chips (`TextChipLayoutDelegate`) and keeps the
/// creator's undo history. Its words are the page's plain text; only their attributes are its own (`ScriptTextStyle`), and they are
/// painted on the text storage directly, which leaves the undo history alone (setting `attributedText` would clear it).
final class ScriptTextView: UITextView {
    var style: ScriptTextStyle {
        didSet { if style != oldValue { restyle() } }
    }

    /// Kept here: the layout manager only holds its delegate weakly.
    private let chipLayout = TextChipLayoutDelegate()

    init(style: ScriptTextStyle) {
        self.style = style
        super.init(frame: .zero, textContainer: nil)
        textLayoutManager?.delegate = chipLayout
        backgroundColor = .clear
        isScrollEnabled = false
        let insets = ScriptTextEditor.textInsets
        textContainerInset = UIEdgeInsets(top: insets.top, left: 0, bottom: insets.bottom, right: 0)
        textContainer.lineFragmentPadding = insets.leading
        tintColor = UIColor(Palette.accText)
        writingToolsBehavior = .limited
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        typingAttributes = style.bodyAttributes
        accessibilityLabel = String(localized: "Script text")
        accessibilityIdentifier = "page.editor"
    }

    required init?(coder: NSCoder) {
        nil
    }

    // MARK: - Words

    /// New words from outside, when the creator isn't editing (the page opening, the AI's draft, a voice preview): no undo history.
    func show(_ text: String) {
        let styled = NSMutableAttributedString(string: text)
        style.apply(to: styled, in: NSRange(location: 0, length: styled.length))
        attributedText = styled
        typingAttributes = style.bodyAttributes
    }

    /// New words from outside while the creator edits (a cue from the bar, a tool): only the part that changed is replaced, as an edit
    /// the keyboard's undo can take back.
    func replace(with text: String) {
        let old = textStorage.string
        let change = ScriptTextOffsets.change(from: old, to: text)
        let removed = ScriptTextOffsets.nsRange(of: change.removed, in: old)
        let inserted = ScriptTextOffsets.nsRange(of: change.inserted, in: text)
        guard let range = textRange(of: removed) else {
            show(text)
            return
        }
        replace(range, withText: (text as NSString).substring(with: inserted))
        restyle(around: NSRange(location: removed.location, length: inserted.length))
    }

    /// Paints the paragraphs around `range` again (everything when nil), after an edit or when the style changes.
    func restyle(around range: NSRange? = nil) {
        let whole = NSRange(location: 0, length: textStorage.length)
        let paragraphs = range.map { (textStorage.string as NSString).paragraphRange(for: NSIntersectionRange($0, whole)) } ?? whole
        textStorage.beginEditing()
        style.apply(to: textStorage, in: paragraphs)
        textStorage.endEditing()
        typingAttributes = style.bodyAttributes
    }

    // MARK: - Cues

    /// The creator is deleting `range` (an empty `replacement`): when that cuts into a cue, the range that takes all of it instead
    /// (`ScriptCueDeletion`), so backspace after "[pause]" leaves no "[paus" behind. Nil when the deletion leaves every cue whole.
    func cueDeletion(replacing range: NSRange, with replacement: String) -> NSRange? {
        guard replacement.isEmpty, range.length > 0 else { return nil }
        let old = textStorage.string
        let new = (old as NSString).replacingCharacters(in: range, with: "")
        guard let completed = ScriptCueDeletion.completing(from: old, to: new) else { return nil }
        let removed = old.count - completed.text.count
        return ScriptTextOffsets.nsRange(of: completed.caret..<(completed.caret + removed), in: old)
    }

    /// Deletes `range` as the keyboard would, so it is one step of the undo history.
    func delete(_ range: NSRange) {
        guard let textRange = textRange(of: range) else { return }
        replace(textRange, withText: "")
    }

    // MARK: - Selection

    /// The selection in characters from the start (a caret is an empty range).
    var characterSelection: Range<Int>? {
        ScriptTextOffsets.characters(of: selectedRange, in: textStorage.string)
    }

    func select(characters range: Range<Int>) {
        let target = ScriptTextOffsets.nsRange(of: range, in: textStorage.string)
        if target != selectedRange { selectedRange = target }
    }

    private func textRange(of range: NSRange) -> UITextRange? {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length) else { return nil }
        return textRange(from: start, to: end)
    }
}
