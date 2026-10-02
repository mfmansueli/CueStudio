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
///
/// The microphone next to the arrow dictates the idea: speak, see the words appear, review them,
/// then send, like a chat. Dictation only writes in the field (`IdeaPromptDraft.hear`, at the
/// insertion point, never over what is there) and never sends anything itself; the arrow stays
/// off until it has stopped and its last words are in. Typed and spoken ideas take the same road.
struct IdeaPromptCard: View {
    @Binding var draft: IdeaPromptDraft
    var base: Color = Palette.surface
    var animatesBackground = true
    /// Why Apple Intelligence can't write now; nil when it can. The arrow is off then, and the note says why.
    var unavailableReason: String?
    let onSubmit: () -> Void

    @Environment(DictationService.self) private var dictation
    @Environment(LanguageService.self) private var languages
    @FocusState private var isFocused: Bool
    @State private var selection: TextSelection?
    /// The height of a line of the field's text, which grows with Dynamic Type.
    @ScaledMetric(relativeTo: .subheadline) private var lineHeight = 20.0

    /// Lines the field grows to before it scrolls.
    private static let visibleLines = 6.0

    private var canSubmit: Bool {
        draft.canSubmit(isAvailable: unavailableReason == nil, isDictating: dictation.isActive)
    }

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
                if let notice = dictation.notice, !dictation.isActive {
                    DictationNoticeView(notice: notice)
                        .transition(.opacity)
                }
                chips
                if let unavailableReason {
                    AIUnavailableNote(reason: unavailableReason)
                }
            }
            .animation(.smooth(duration: 0.2), value: draft.idea)
            .animation(.smooth(duration: 0.2), value: dictation.isActive)
            .animation(.smooth(duration: 0.2), value: dictation.notice)
        }
        .accessibilityElement(children: .contain)
        .onChange(of: dictation.state) { _, state in
            if state == .idle { finishDictation() }
            if state == .listening { AccessibilityNotification.Announcement(String(localized: "Listening…")).post() }
        }
        .onChange(of: draft.text) {
            draft.textChanged()
            // Editing is a fresh start: an old "didn't catch anything" is no longer news.
            if !dictation.isActive, dictation.notice != nil { dictation.dismissNotice() }
        }
        // Stopped and interrupted notes pass by themselves; the ones with something to do stay.
        .task(id: dictation.notice) {
            guard let notice = dictation.notice, notice == .interrupted || notice == .nothingHeard else { return }
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled, dictation.notice == notice { dictation.dismissNotice() }
        }
    }

    // MARK: - Pieces

    private var field: some View {
        VStack(alignment: .leading, spacing: 0) {
            if dictation.isActive {
                DictationStatusRow(state: dictation.state, level: dictation.level)
                    .padding(.leading, 16)
                    .padding(.top, 12)
                    .transition(.opacity)
            }
            HStack(alignment: .bottom, spacing: 0) {
                textArea
                DictationButton(state: dictation.state, action: toggleDictation)
                sendButton
            }
            .padding(.leading, 16)
            .padding(.trailing, 1)
        }
        .frame(minHeight: 46)
        .background(Palette.insetField, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    /// The field to type in; while dictating, the same words read-only, which keeps the newest in
    /// view as they grow (a field that isn't being edited wouldn't scroll to them). Tapping them stops
    /// the dictation, so the next tap can type.
    @ViewBuilder private var textArea: some View {
        if dictation.isActive {
            ViewThatFits(in: .vertical) {
                transcript
                ScrollView { transcript }
                    .defaultScrollAnchor(draft.dictation?.after.isEmpty == false ? .top : .bottom)
            }
            .frame(maxHeight: lineHeight * Self.visibleLines + 24)
            .contentShape(Rectangle())
            .onTapGesture { dictation.stop() }
            .accessibilityIdentifier("empty.ideaTranscript")
        } else {
            TextField(text: $draft.text, selection: $selection, prompt: placeholder, axis: .vertical) {
                Text("Tell or write your idea…")
            }
            .lineLimit(1...Int(Self.visibleLines))
            .focused($isFocused)
            .submitLabel(.send)
            .onSubmit(submit)
            .font(.subheadline)
            .foregroundStyle(Palette.ink)
            .tint(Palette.accText)
            .padding(.vertical, 12)
            .writingToolsBehavior(.limited)
            .accessibilityIdentifier("empty.ideaField")
        }
    }

    private var placeholder: Text {
        Text("Tell or write your idea…").foregroundStyle(Palette.ink2)
    }

    private var transcript: some View {
        Group {
            if draft.text.isEmpty {
                placeholder
            } else {
                Text(draft.text).foregroundStyle(Palette.ink)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private var sendButton: some View {
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
        if draft.toggle(option), !dictation.isActive { isFocused = true }
    }

    /// The microphone: starts dictating, or stops (also while it is still getting ready).
    private func toggleDictation() {
        Haptics.selection()
        if dictation.isActive {
            dictation.stop()
        } else {
            startDictation()
        }
    }

    /// Dictation writes at the caret (the end when the field has none), after what is there and
    /// never over it. The keyboard goes down so the words have room.
    private func startDictation() {
        draft.beginDictation(caret: IdeaPromptDraft.caretOffset(of: selection, in: draft.text))
        isFocused = false
        let request = languages.dictationRequest(existingText: draft.text)
        Task {
            await dictation.start(language: request) { draft.hear($0) }
            // It couldn't start (no permission, no recognizer): nothing was written, nothing to keep open.
            if !dictation.isActive { finishDictation() }
        }
    }

    /// The words stay where they were written, and the caret goes after them, ready to type on.
    private func finishDictation() {
        guard let end = draft.endDictation() else { return }
        let text = draft.text
        selection = TextSelection(insertionPoint: text.index(text.startIndex, offsetBy: min(end, text.count)))
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
        .previewEnvironment(seeded: false)
}
#endif
