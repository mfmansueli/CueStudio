//
//  IdeaPromptCard.swift
//  Cue Studio
//

import SwiftUI

/// The empty Scripts screen's way in: "What's the idea?", and a field to answer it. It looks like the
/// Prompt card (`PromptCardSurface`) but holds a draft. The field is a compact preview of it, about
/// three lines tall, that scrolls inside when the idea is longer, so the card never grows while the
/// idea does. Writing and speaking happen in the composer (`IdeaComposerSheet`): tapping the field
/// opens it with the keyboard, the microphone opens it dictating, and the arrow sends the draft to
/// the same generation flow as Generate › Prompt. The draft is the one kept by `IdeaDraftService`.
///
/// Under the field, "Write in my voice" (`WriteInMyVoiceRow`) shares its state with Generate.
struct IdeaPromptCard: View {
    var base: Color = Palette.surface
    var animatesBackground = true
    /// Why Apple Intelligence can't write now; nil when it can. The arrow is off then, and the note says why.
    var unavailableReason: String?
    let onCompose: () -> Void
    let onDictate: () -> Void
    let onSubmit: () -> Void

    @Environment(IdeaDraftService.self) private var ideaDraft
    @Environment(DictationService.self) private var dictation
    /// The height of a line of the field's text, which grows with Dynamic Type.
    @ScaledMetric(relativeTo: .subheadline) private var lineHeight = 20.0

    /// Lines of the field, fixed: a longer idea scrolls inside it.
    private static let visibleLines = 3.0

    private var canSubmit: Bool {
        ideaDraft.canSubmit(isAvailable: unavailableReason == nil, isDictating: dictation.isActive)
    }

    var body: some View {
        PromptCardSurface(base: base, animatesBackground: animatesBackground) {
            VStack(alignment: .leading, spacing: 12) {
                PromptCardHeader(title: "What’s the idea?", animatesBackground: animatesBackground)
                Text("Tell us what you want to record. Cue writes the script.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                field
                WriteInMyVoiceRow()
                if let unavailableReason {
                    AIUnavailableNote(reason: unavailableReason)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Pieces

    /// The preview of the draft, with the microphone and the arrow at its end. Their places never move.
    private var field: some View {
        HStack(alignment: .bottom, spacing: 0) {
            preview
                .padding(.leading, 16)
            DictationButton(
                state: dictation.state,
                hint: "Opens the idea editor and starts listening.",
                action: toggleDictation
            )
            sendButton
        }
        .padding(.trailing, 1)
        .background(Palette.insetField, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    /// The draft, or the placeholder, in a fixed-height area: it scrolls when the text is longer, and
    /// a tap anywhere on it opens the composer (a scroll doesn't).
    private var preview: some View {
        ScrollView {
            Group {
                if ideaDraft.text.isEmpty {
                    Text("Tell or write your idea…").foregroundStyle(Palette.ink2)
                } else {
                    Text(ideaDraft.text).foregroundStyle(Palette.ink)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: lineHeight * Self.visibleLines + 24)
        .contentShape(Rectangle())
        .onTapGesture(perform: onCompose)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Your idea"))
        .accessibilityValue(ideaDraft.text.isEmpty ? Text("Tell or write your idea…") : Text(ideaDraft.text))
        .accessibilityHint(Text("Opens the idea editor."))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onCompose)
        .accessibilityIdentifier("empty.ideaField")
    }

    private var sendButton: some View {
        Button(action: onSubmit) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.accInk)
                .frame(width: 34, height: 34)
                .background(Palette.acc.opacity(canSubmit ? 1 : 0.35), in: Circle())
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .accessibilityLabel(Text("Generate script"))
        .accessibilityIdentifier("empty.ideaSubmit")
    }

    // MARK: - Actions

    /// The microphone opens the composer listening; while a dictation is still finishing, it stops it.
    private func toggleDictation() {
        Haptics.selection()
        if dictation.isActive {
            dictation.stop()
        } else {
            onDictate()
        }
    }
}

#if DEBUG
#Preview {
    IdeaPromptCard(onCompose: {}, onDictate: {}, onSubmit: {})
        .padding()
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
