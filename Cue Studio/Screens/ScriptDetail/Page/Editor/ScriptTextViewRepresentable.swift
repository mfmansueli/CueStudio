//
//  ScriptTextViewRepresentable.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// `ScriptTextView` in the page. The words, the selection and the keyboard go both ways: what the creator types, selects or undoes
/// goes up to the page; what the page changes (the AI, a tool, a cue from the bar) comes down. A change the editor reported is not
/// taken back for one from outside (`lastReported`), and nothing goes up while the page's own change is being applied (`isApplying`).
struct ScriptTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: Range<Int>?
    let style: ScriptTextStyle
    let minimumHeight: CGFloat
    var focus: FocusState<ScriptPageFocus?>.Binding
    let undo: ScriptEditorUndo?
    let onEdit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ScriptTextView {
        let view = ScriptTextView(style: style)
        view.delegate = context.coordinator
        context.coordinator.watchOtherFields(for: view)
        view.show(text)
        context.coordinator.lastReported = text
        if let selection {
            view.select(characters: selection)
            context.coordinator.lastReportedSelection = selection
        }
        return view
    }

    func updateUIView(_ view: ScriptTextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.isApplying = true
        defer { coordinator.isApplying = false }
        view.style = style
        if text != coordinator.lastReported {
            if view.isFirstResponder {
                view.replace(with: text)
            } else {
                view.show(text)
            }
            coordinator.lastReported = text
            view.invalidateIntrinsicContentSize()
            undo?.refresh()
        }
        if selection != coordinator.lastReportedSelection {
            if let selection { view.select(characters: selection) }
            coordinator.lastReportedSelection = selection
        }
        followFocus(view, coordinator: coordinator)
    }

    static func dismantleUIView(_ view: ScriptTextView, coordinator: Coordinator) {
        coordinator.parent.undo?.detach(from: view.undoManager)
        coordinator.stopWatchingOtherFields()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView view: ScriptTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? view.bounds.width
        guard width > 0, width.isFinite else { return nil }
        let fitting = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(minimumHeight, fitting.height))
    }

    /// The page moves the keyboard with its focus (`.text` after the title or an alert, nil for Done): the text view follows when the
    /// page's focus changes, on the next turn of the run loop, so it never changes first responder in the middle of an update. Only on
    /// a change: an alert's field that takes the keyboard while the page still says `.text` keeps it.
    private func followFocus(_ view: ScriptTextView, coordinator: Coordinator) {
        let wantsKeyboard = focus.wrappedValue == .text
        let changed = wantsKeyboard != coordinator.pageWantedKeyboard
        coordinator.pageWantedKeyboard = wantsKeyboard
        guard changed, wantsKeyboard != view.isFirstResponder, view.window != nil else { return }
        let focus = focus
        DispatchQueue.main.async {
            if focus.wrappedValue == .text, !view.isFirstResponder {
                view.becomeFirstResponder()
            } else if focus.wrappedValue != .text, view.isFirstResponder {
                view.resignFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ScriptTextViewRepresentable
        var lastReported = ""
        var lastReportedSelection: Range<Int>?
        var isApplying = false
        /// Whether the page's focus last asked for the keyboard here.
        var pageWantedKeyboard = false
        /// Where the creator's edit happened, so only its paragraphs are painted again.
        private var pendingEdit: NSRange?
        /// A field elsewhere that has the keyboard (the "New cue" alert's, the title), and what tells when one starts and ends.
        private weak var otherField: UITextField?
        private var fieldObservers: [NSObjectProtocol] = []

        init(parent: ScriptTextViewRepresentable) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.undo?.attach(textView.undoManager)
            pageWantedKeyboard = true
            if parent.focus.wrappedValue != .text { parent.focus.wrappedValue = .text }
        }

        /// The keyboard left the words. When another field took it while the page still writes (the "New cue" alert), the page
        /// keeps its focus and the words take the keyboard back when that field is done: putting the page's focus to nil would make
        /// SwiftUI end editing everywhere, the alert's field too. Otherwise (Done, the keyboard swiped away) the page loses its focus.
        func textViewDidEndEditing(_ textView: UITextView) {
            // On the next turn: the field taking the keyboard only says so after this one has let it go.
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView, !textView.isFirstResponder else { return }
                if self.parent.focus.wrappedValue == .text, self.otherField != nil { return }
                self.pageWantedKeyboard = false
                if self.parent.focus.wrappedValue == .text { self.parent.focus.wrappedValue = nil }
            }
        }

        func watchOtherFields(for view: ScriptTextView) {
            let center = NotificationCenter.default
            fieldObservers = [
                center.addObserver(forName: UITextField.textDidBeginEditingNotification, object: nil, queue: .main) { [weak self] note in
                    let field = note.object as? UITextField
                    MainActor.assumeIsolated { self?.otherField = field }
                },
                center.addObserver(forName: UITextField.textDidEndEditingNotification, object: nil, queue: .main) { [weak self, weak view] note in
                    let field = note.object as? UITextField
                    MainActor.assumeIsolated { self?.otherFieldEnded(field, view: view) }
                },
            ]
        }

        func stopWatchingOtherFields() {
            fieldObservers.forEach(NotificationCenter.default.removeObserver)
            fieldObservers = []
        }

        /// The field that borrowed the keyboard is done: back to the words if the page still writes and nothing else took it.
        private func otherFieldEnded(_ field: UITextField?, view: ScriptTextView?) {
            guard field === otherField else { return }
            otherField = nil
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view, self.otherField == nil, !view.isFirstResponder, view.window != nil,
                      self.parent.focus.wrappedValue == .text else { return }
                if !view.becomeFirstResponder() {
                    self.pageWantedKeyboard = false
                    self.parent.focus.wrappedValue = nil
                }
            }
        }

        func textView(_ textView: UITextView, shouldChangeTextInRanges ranges: [NSValue], replacementText text: String) -> Bool {
            let ranges = ranges.map(\.rangeValue)
            if let first = ranges.first {
                let end = ranges.map(NSMaxRange).max() ?? NSMaxRange(first)
                pendingEdit = NSRange(location: first.location, length: end - first.location + (text as NSString).length)
            }
            // Deleting into a cue deletes all of it, as one step the creator can undo.
            guard !isApplying, ranges.count == 1, let view = textView as? ScriptTextView,
                  let whole = view.cueDeletion(replacing: ranges[0], with: text) else { return true }
            view.delete(whole)
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let view = textView as? ScriptTextView else { return }
            let edited = pendingEdit
            pendingEdit = nil
            parent.undo?.refresh()
            // A change from the page paints itself (`ScriptTextView.replace(with:)`). Painting the words while a word is still being
            // composed (Japanese, Chinese…) would end the composition.
            guard !isApplying else { return }
            if view.markedTextRange == nil { view.restyle(around: edited) }
            let plain = view.textStorage.string
            if plain != lastReported {
                lastReported = plain
                parent.text = plain
                parent.onEdit()
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let view = textView as? ScriptTextView, view.markedTextRange == nil else { return }
            // A word typed after a cue or inside the AI's passage is a plain word.
            view.typingAttributes = view.style.bodyAttributes
            guard !isApplying else { return }
            let range = view.characterSelection
            lastReportedSelection = range
            if parent.selection != range { parent.selection = range }
        }
    }
}
