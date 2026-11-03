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

    /// While the creator types within one paragraph (`willEdit`): where it starts, the whole height measured when the typing in it began,
    /// and the paragraph's own height then (`ParagraphGauge`). Anything else (the page's own words, a new look or width, a return typed
    /// or deleted, another paragraph, an undo) measures the whole script again.
    private var typingParagraph: (start: Int, height: CGFloat, paragraph: CGFloat)?
    /// The paragraph of the creator's last edit (`willEdit`) and the words' length after it: a change that didn't say so first (an undo,
    /// words set from outside) doesn't leave that length, and is measured whole.
    private var announcedEdit: (paragraphStart: Int, length: Int)?
    /// The last height told.
    private var toldHeight: CGFloat?
    /// More than typing changes the height by in one go (a few lines): measured whole.
    private static let typingHeightJump: CGFloat = 120
    private lazy var gauge = ParagraphGauge(lineFragmentPadding: textContainer.lineFragmentPadding, chips: chipLayout)

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

    override func layoutSubviews() {
        ScriptTypingTimeline.measure("Layout") { super.layoutSubviews() }
    }

    // MARK: - Words

    /// New words from outside, when the creator isn't editing (the page opening, the AI's draft, a voice preview): no undo history.
    func show(_ text: String) {
        typingParagraph = nil
        let styled = NSMutableAttributedString(string: text)
        style.apply(to: styled, in: NSRange(location: 0, length: styled.length))
        attributedText = styled
        typingAttributes = style.bodyAttributes
    }

    /// New words from outside while the creator edits (a cue from the bar, a tool): only the part that changed is replaced, as an edit
    /// the keyboard's undo can take back.
    func replace(with text: String) {
        typingParagraph = nil
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
        if range == nil { typingParagraph = nil }
        let whole = NSRange(location: 0, length: textStorage.length)
        let paragraphs = range.map { (textStorage.string as NSString).paragraphRange(for: Self.clamped($0, to: whole.length)) } ?? whole
        textStorage.beginEditing()
        style.apply(to: textStorage, in: paragraphs)
        textStorage.endEditing()
        typingAttributes = style.bodyAttributes
    }

    /// After the creator's own edit around `range`: its paragraph is painted again only when the edit can have changed how it looks (it
    /// has a cue, or the AI's passage is on the page). A letter typed among plain words already looks like them (`typingAttributes`), and
    /// painting a long paragraph again on every letter is what typing in a script the AI wrote paid (03/11/2026).
    func restyleAfterEdit(around range: NSRange?) {
        guard let range, style.passage == nil else { return restyle(around: range) }
        let string = textStorage.string as NSString
        let paragraph = string.paragraphRange(for: Self.clamped(range, to: string.length))
        guard string.rangeOfCharacter(from: Self.cueBrackets, options: [], range: paragraph).location == NSNotFound else {
            return restyle(around: range)
        }
        typingAttributes = style.bodyAttributes
    }

    private static let cueBrackets = CharacterSet(charactersIn: "[]")

    /// `range` kept inside words `length` long. (`NSIntersectionRange` makes an empty range, a caret, into {0, 0}: the first paragraph.)
    private static func clamped(_ range: NSRange, to length: Int) -> NSRange {
        let location = min(max(range.location, 0), length)
        return NSRange(location: location, length: min(max(range.length, 0), length - location))
    }

    // MARK: - Size

    /// The creator is about to replace `ranges` with `replacement` (`textView(_:shouldChangeTextInRanges:replacementText:)`): within the
    /// paragraph being typed in, the next height is that paragraph's (`fittingHeight`).
    func willEdit(_ ranges: [NSRange], with replacement: String) {
        let string = textStorage.string as NSString
        guard ranges.count == 1 else {
            typingParagraph = nil
            announcedEdit = nil
            return
        }
        let range = Self.clamped(ranges[0], to: string.length)
        let paragraph = string.paragraphRange(for: NSRange(location: range.location, length: 0))
        // A return typed or deleted makes or joins paragraphs: what is below moves.
        let returns = CharacterSet.newlines
        let keepsParagraphs = (replacement as NSString).rangeOfCharacter(from: returns).location == NSNotFound
            && string.rangeOfCharacter(from: returns, options: [], range: range).location == NSNotFound
        if !keepsParagraphs || typingParagraph?.start != paragraph.location { typingParagraph = nil }
        announcedEdit = (paragraph.location, string.length - range.length + (replacement as NSString).length)
    }

    /// How tall its words are at `width`. While the creator types in one paragraph, the whole as measured when that began plus what the
    /// paragraph grew by (`typingParagraph`); otherwise UIKit's own measure, which lays the whole script out afresh. The same height every
    /// way (`ScriptTextViewTests`).
    func fittingHeight(for width: CGFloat) -> CGFloat {
        guard abs(bounds.width - width) < 0.5 else {
            typingParagraph = nil
            return sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        }
        if let typed = typedHeight() { return typed }
        let height = super.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        toldHeight = height
        // The paragraph of the last edit, if the words are still as that edit left them: typing on in it is measured from it.
        if let edit = announcedEdit, edit.length == textStorage.length, let paragraph = paragraphHeight(at: edit.paragraphStart) {
            typingParagraph = (edit.paragraphStart, height, paragraph)
        } else {
            typingParagraph = nil
        }
        return height
    }

    /// The next height comes from the paragraph being typed in: the words are what the creator's edits there made.
    var measuresTypedParagraph: Bool {
        guard let typing = typingParagraph, let edit = announcedEdit else { return false }
        return edit.paragraphStart == typing.start && edit.length == textStorage.length
    }

    /// The whole as measured when the typing in this paragraph began, plus what the paragraph grew by; nil when the words aren't what the
    /// creator's edits made, or the change is more than typing makes.
    private func typedHeight() -> CGFloat? {
        guard measuresTypedParagraph, let typing = typingParagraph, let paragraph = paragraphHeight(at: typing.start) else { return nil }
        let height = typing.height + paragraph - typing.paragraph
        guard abs(height - (toldHeight ?? height)) <= Self.typingHeightJump else { return nil }
        toldHeight = height
        return height
    }

    /// The height of the paragraph that starts at `start`, laid out on its own (`ParagraphGauge`).
    private func paragraphHeight(at start: Int) -> CGFloat? {
        let string = textStorage.string as NSString
        guard start < string.length else { return nil }
        let paragraph = string.paragraphRange(for: NSRange(location: start, length: 0))
        guard paragraph.location == start else { return nil }
        return gauge.height(of: textStorage.attributedSubstring(from: paragraph), width: textContainer.size.width)
    }

    #if DEBUG
    /// The words' height in a new editor that has never been typed in (`ScriptTypingProbe`).
    static func freshHeight(of text: String, style: ScriptTextStyle, width: CGFloat) -> CGFloat {
        let fresh = ScriptTextView(style: style)
        fresh.frame = CGRect(x: 0, y: 0, width: width, height: 100)
        fresh.show(text)
        return fresh.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }
    #endif

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
