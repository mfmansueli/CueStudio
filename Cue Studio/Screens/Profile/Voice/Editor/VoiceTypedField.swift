//
//  VoiceTypedField.swift
//  Cue Studio
//

import SwiftUI

/// A field for the creator's own words in the voice editor ("+ Something else"): checked as it is added (2–40 characters, no repeats, nothing Apple
/// Intelligence refuses, a "Did you mean…" for a likely typo) and the limit said as "Max n". The one place that turns what the service answers
/// (`VoiceEditResult`) into a line under the field or a toast, so every answer of the editor behaves the same.
struct VoiceTypedField: View {
    let placeholder: String
    /// Tries to keep the text; `keepingTyped` is true after "Keep mine".
    let submit: (_ text: String, _ keepingTyped: Bool) -> VoiceEditResult
    var addLabel = String(localized: "Add")
    /// The text the field starts with: the answer the creator already typed for a field that holds one.
    var initialText = ""
    /// Empty after a text is added (a list of answers), or keeps showing it (a single answer).
    var clearsWhenAdded = true
    var identifier = "voice.field"

    @Environment(ToastService.self) private var toast
    @State private var text = ""
    @State private var feedback: Feedback?
    @FocusState private var isFocused: Bool

    private enum Feedback: Equatable {
        case message(String)
        case typo(suggestion: String, original: String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit { add() }
                    .accessibilityIdentifier(identifier)
                Button(addLabel) { add() }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty && initialText.isEmpty)
                    .accessibilityIdentifier("\(identifier).add")
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
            if let feedback { feedbackView(feedback) }
        }
        .onAppear { if text.isEmpty { text = initialText } }
    }

    private func add(keepingTyped: Bool = false) {
        switch submit(text, keepingTyped) {
        case .added:
            if clearsWhenAdded { text = "" }
            feedback = nil
            isFocused = false
        case .removed:
            text = ""
            feedback = nil
            isFocused = false
        case .alreadyThere:
            // Already there: it stays selected, and the field says so.
            if clearsWhenAdded { text = "" }
            feedback = .message(String(localized: "Already added."))
        case .limit(let message):
            feedback = nil
            toast.show(message)
        case .rejected(let check):
            feedback = check.message.map(Feedback.message)
        case .suggest(let suggestion, let original):
            feedback = .typo(suggestion: suggestion, original: original)
        }
    }

    @ViewBuilder
    private func feedbackView(_ feedback: Feedback) -> some View {
        switch feedback {
        case .message(let text):
            Text(text)
                .font(.footnote)
                .foregroundStyle(Palette.warnText)
                .accessibilityIdentifier("voice.feedback")
        case .typo(let suggestion, let original):
            HStack(spacing: 10) {
                Text("Did you mean “\(suggestion)”?")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Use") {
                    text = suggestion
                    add()
                }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("voice.typo.use")
                Button("Keep mine") {
                    text = original
                    add(keepingTyped: true)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("voice.typo.keep")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("voice.feedback")
        }
    }
}
