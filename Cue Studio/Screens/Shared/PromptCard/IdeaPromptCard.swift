//
//  IdeaPromptCard.swift
//  Cue Studio
//

import SwiftUI

/// The empty Scripts screen's way in: "What's the idea?", a field to answer it and three kinds of
/// video to start from. It looks like the Prompt card (`PromptCardSurface`) but is a real field:
/// the arrow sends the text, and the kind picked with it, to the same generation flow as Generate ›
/// Prompt (`onSubmit`). A chip only picks the question shown above the field: it never writes,
/// replaces or sends anything by itself, and the arrow is off while the field is empty.
struct IdeaPromptCard: View {
    @Binding var draft: IdeaPromptDraft
    var base: Color = Palette.surface
    var animatesBackground = true
    /// Why Apple Intelligence can't write now; nil when it can. The arrow is off then, and the note says why.
    var unavailableReason: String?
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var canSubmit: Bool { draft.canSubmit(isAvailable: unavailableReason == nil) }

    var body: some View {
        PromptCardSurface(base: base, animatesBackground: animatesBackground) {
            VStack(alignment: .leading, spacing: 12) {
                PromptCardHeader(title: "What’s the idea?", animatesBackground: animatesBackground)
                Text("Tell us what you want to record. Cue writes the script.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                if let idea = draft.idea {
                    // The question stays while there is text in the field: it guides, it never replaces.
                    Text(idea.question)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accText)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                        .accessibilityIdentifier("empty.ideaQuestion")
                }
                field
                chips
                if let unavailableReason {
                    AIUnavailableNote(reason: unavailableReason)
                }
            }
            .animation(.smooth(duration: 0.2), value: draft.idea)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Pieces

    private var field: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(text: $draft.text, prompt: Text("What’s your video about?").foregroundStyle(Palette.ink2), axis: .vertical) {
                Text("Describe your video")
            }
            .lineLimit(1...5)
            .focused($isFocused)
            .submitLabel(.send)
            .onSubmit(submit)
            .font(.subheadline)
            .foregroundStyle(Palette.ink)
            .tint(Palette.accText)
            .padding(.vertical, 12)
            .writingToolsBehavior(.limited)
            .accessibilityIdentifier("empty.ideaField")
            Button(action: submit) {
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
        .padding(.leading, 16)
        .padding(.trailing, 1)
        .frame(minHeight: 46)
        .background(Palette.insetField, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    private var chips: some View {
        FlowLayout(spacing: 8, lineSpacing: 0) {
            ForEach(ScriptIdea.allCases) { option in
                Button { toggle(option) } label: {
                    FilterChip(label: option.label, isSelected: draft.idea == option)
                        .fixedSize()
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("empty.idea.\(option.rawValue)")
            }
        }
    }

    // MARK: - Actions

    /// One at a time; the same chip again goes back to a free idea. Picking one asks its question
    /// and takes the keyboard to the field; the text in it is never touched.
    private func toggle(_ option: ScriptIdea) {
        Haptics.selection()
        if draft.toggle(option) { isFocused = true }
    }

    private func submit() {
        guard canSubmit else { return }
        isFocused = false
        onSubmit()
    }
}

#if DEBUG
#Preview {
    @Previewable @State var draft = IdeaPromptDraft()
    IdeaPromptCard(draft: $draft, onSubmit: {})
        .padding()
        .background(Palette.bg)
}
#endif
