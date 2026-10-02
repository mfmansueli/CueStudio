//
//  ParagraphTextView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// One paragraph of the script being written. It grows with its text, so the paragraphs stack in
/// one scroll view; Return, a paste with line breaks and Backspace at the start are the editor's
/// to handle (a new paragraph, or a join), and where the caret goes comes from `focus`.
struct ParagraphTextView: UIViewRepresentable {
    let index: Int
    let text: String
    let size: ScriptTextSize
    let focus: ParagraphFocus?
    var onChange: (String) -> Void
    /// The new text of the paragraph with a line break in it, and where the caret was in it.
    var onLineBreak: (String, Int) -> Void
    var onBackspaceAtStart: () -> Void
    var onMove: (Int) -> Void
    var onCaret: (Int) -> Void
    var onBeginEditing: () -> Void
    var onEndEditing: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ParagraphUITextView {
        let view = ParagraphUITextView()
        view.delegate = context.coordinator
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.tintColor = UIColor(Palette.acc)
        view.adjustsFontForContentSizeCategory = true
        view.autocapitalizationType = .sentences
        view.writingToolsBehavior = .complete
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.accessibilityLabel = String(localized: "Script text")
        view.accessibilityIdentifier = "editor.paragraph.\(index)"
        context.coordinator.parent = self
        apply(to: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ view: ParagraphUITextView, context: Context) {
        context.coordinator.parent = self
        view.accessibilityIdentifier = "editor.paragraph.\(index)"
        apply(to: view, coordinator: context.coordinator)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView view: ParagraphUITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitted = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    // MARK: - Applying

    private func apply(to view: ParagraphUITextView, coordinator: Coordinator) {
        view.onBackspaceAtStart = { onBackspaceAtStart() }
        view.onArrowUpAtStart = { onMove(-1) }
        view.onArrowDownAtEnd = { onMove(1) }
        let attributes = Self.attributes(for: size)
        if coordinator.appliedSize != size {
            coordinator.appliedSize = size
            view.font = attributes[.font] as? UIFont
            view.typingAttributes = attributes
            view.attributedText = NSAttributedString(string: text, attributes: attributes)
        } else if view.text != text {
            view.attributedText = NSAttributedString(string: text, attributes: attributes)
        }
        if let focus, focus.token != coordinator.handledFocus {
            coordinator.handledFocus = focus.token
            if focus.index == index {
                // The view may not be in a window yet (a paragraph just made by Return).
                Task { @MainActor [weak view] in
                    guard let view else { return }
                    view.becomeFirstResponder()
                    let offset = min(max(0, focus.offset), (view.text as NSString).length)
                    view.selectedRange = NSRange(location: offset, length: 0)
                    view.layoutIfNeeded()
                    view.scrollCaretIntoView()
                }
            } else if focus.index == nil, view.isFirstResponder {
                view.resignFirstResponder()
            }
        }
    }

    /// The font scales with Dynamic Type from `size` at the default setting.
    private static func attributes(for size: ScriptTextSize) -> [NSAttributedString.Key: Any] {
        let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: size.points))
        let style = NSMutableParagraphStyle()
        style.lineSpacing = size.points * 0.32
        return [
            .font: font,
            .foregroundColor: UIColor(Palette.ink).withAlphaComponent(0.93),
            .paragraphStyle: style,
        ]
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ParagraphTextView?
        var appliedSize: ScriptTextSize?
        var handledFocus: UUID?

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text.contains(where: \.isNewline), let parent else { return true }
            let current = textView.text as NSString
            let replaced = current.replacingCharacters(in: range, with: text)
            parent.onLineBreak(replaced, range.location + (text as NSString).length)
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            // Text being composed (Japanese, Chinese) isn't the paragraph's text yet.
            parent?.onChange(textView.text)
            (textView as? ParagraphUITextView)?.scrollCaretIntoView()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard textView.isFirstResponder else { return }
            parent?.onCaret(textView.selectedRange.location)
            (textView as? ParagraphUITextView)?.scrollCaretIntoView()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent?.onBeginEditing()
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent?.onEndEditing()
        }
    }
}
