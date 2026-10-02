//
//  IdeaComposerSheet.swift
//  Cue Studio
//

import SwiftUI

/// Where an idea is written or spoken at ease: a roomy text area that scrolls, the microphone, and
/// "Create script". Opened from the idea card, either with the keyboard up or dictating (after the
/// sheet is shown and the microphone allowed). The text is the card's draft (`IdeaDraftService`):
/// closing the sheet keeps it, and reopening shows exactly that.
///
/// Dictation writes only in its own segment of the draft (`IdeaPromptDraft.hear`), shows the newest
/// words while it listens, and never sends anything: after it stops the creator reviews, types or
/// dictates on, and only "Create script" goes to the generation flow. That button is off while the
/// microphone is on or its last words are still coming in, and while there is nothing to send.
/// Closing the sheet stops the dictation and lets the recognizer finish the last words.
struct IdeaComposerSheet: View {
    /// Starts listening once the sheet is shown, instead of focusing the text.
    let startsDictating: Bool
    /// Why Apple Intelligence can't write now; nil when it can. Typing still works, and says why.
    var unavailableReason: String?

    @Environment(IdeaDraftService.self) private var ideaDraft
    @Environment(DictationService.self) private var dictation
    @Environment(LanguageService.self) private var languages
    @Environment(PresentationService.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isFocused: Bool
    @State private var selection: TextSelection?
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var hasStarted = false
    @State private var isSending = false

    private var canSubmit: Bool {
        !isSending && ideaDraft.canSubmit(isAvailable: unavailableReason == nil, isDictating: dictation.isActive)
    }

    /// While the words are added at the end, the view follows them; in the middle of a text it stays put.
    private var followsEnd: Bool {
        ideaDraft.draft.dictation?.after.isEmpty != false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(title: String(localized: "Tell your idea"), subtitle: nil, onClose: { dismiss() })
            statusRow
            textArea
            if let notice = dictation.notice, !dictation.isActive {
                DictationNoticeView(notice: notice)
                    .transition(.opacity)
            }
            if let unavailableReason {
                AIUnavailableNote(reason: unavailableReason)
            }
            bottomBar
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
        .animation(.smooth(duration: 0.2), value: dictation.notice)
        .presentationDetents([.large])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("ideaComposer.sheet")
        .task { await begin() }
        .onChange(of: dictation.state) { _, state in
            if state == .idle { finishDictation() }
            if state == .listening { AccessibilityNotification.Announcement(String(localized: "Listening…")).post() }
        }
        // The app leaves the foreground: the microphone is let go, and the words heard stay.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { dictation.interrupt() }
        }
        // Closing the sheet (or sending the idea on) stops the microphone; the recognizer finishes
        // the last words into the draft, which outlives this sheet.
        .onDisappear {
            if dictation.isActive { dictation.stop() }
        }
    }

    // MARK: - Pieces

    /// "Listening…" with a waveform, in a row that is always there, so the text area keeps its size
    /// when the dictation starts and stops.
    private var statusRow: some View {
        ZStack(alignment: .leading) {
            if dictation.isActive {
                DictationStatusRow(state: dictation.state, level: dictation.level)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
        .animation(.smooth(duration: 0.2), value: dictation.isActive)
    }

    /// The editor, or while dictating the same words read-only (a text view that isn't being edited
    /// wouldn't scroll to the newest). Tapping them stops the dictation, so the next tap can type.
    private var textArea: some View {
        ZStack {
            if dictation.isActive {
                transcript
            } else {
                editor
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.insetField, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if ideaDraft.text.isEmpty {
                placeholder
                    .padding(EdgeInsets(top: 14 + 8, leading: 16 + 5, bottom: 0, trailing: 16))
                    .allowsHitTesting(false)
            }
            TextEditor(text: textBinding, selection: $selection)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .font(.body)
                .foregroundStyle(Palette.ink)
                .tint(Palette.accText)
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                .writingToolsBehavior(.limited)
                .accessibilityLabel(Text("Your idea"))
                .accessibilityIdentifier("ideaComposer.textField")
        }
    }

    private var transcript: some View {
        ScrollView {
            Group {
                if ideaDraft.text.isEmpty {
                    placeholder
                } else {
                    Text(ideaDraft.text).foregroundStyle(Palette.ink)
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 22, leading: 21, bottom: 22, trailing: 21))
        }
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(followsEnd ? .bottom : .top)
        .onChange(of: ideaDraft.text) {
            if followsEnd { scrollPosition.scrollTo(edge: .bottom) }
        }
        .contentShape(Rectangle())
        .onTapGesture { dictation.stop() }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("empty.ideaTranscript")
    }

    private var placeholder: some View {
        Text("Tell or write your idea…")
            .font(.body)
            .foregroundStyle(Palette.ink2)
    }

    /// The microphone starts or resumes the dictation and, while it listens, is the way to stop. The
    /// primary button creates the script from what is written, once nothing is still being heard.
    private var bottomBar: some View {
        HStack(spacing: 12) {
            DictationButton(
                state: dictation.state,
                identifier: "ideaComposer.dictate",
                action: toggleDictation
            )
            Button(action: submit) {
                Label("Create script", systemImage: "sparkles")
            }
            .buttonStyle(.cuePrimary(.large))
            .disabled(!canSubmit)
            .accessibilityIdentifier("ideaComposer.createButton")
        }
    }

    private var textBinding: Binding<String> {
        Binding(get: { ideaDraft.text }, set: { ideaDraft.text = $0 })
    }

    // MARK: - Actions

    /// Once the sheet is shown: dictate when it was opened by the microphone, otherwise take the keyboard.
    private func begin() async {
        guard !hasStarted else { return }
        hasStarted = true
        // A dictation that finished while the sheet was closed leaves its segment behind.
        if !dictation.isActive { ideaDraft.endDictation() }
        if startsDictating {
            startDictation()
        } else {
            try? await Task.sleep(for: .milliseconds(250))
            isFocused = true
        }
    }

    private func toggleDictation() {
        Haptics.selection()
        if dictation.isActive {
            dictation.stop()
        } else {
            startDictation()
        }
    }

    /// Dictation writes at the caret (the end when the text has none), after what is there and never
    /// over it. The keyboard goes down so the words have room.
    private func startDictation() {
        guard dictation.state == .idle else { return }
        ideaDraft.beginDictation(caret: IdeaPromptDraft.caretOffset(of: selection, in: ideaDraft.text))
        isFocused = false
        let request = languages.dictationRequest(existingText: ideaDraft.text)
        // The words go to the draft itself, not through this view: they may still arrive after the sheet is gone.
        let draft = ideaDraft
        let service = dictation
        Task {
            await service.start(language: request) { draft.hear($0) }
            // It couldn't start (no permission, no recognizer): nothing was written, nothing to keep open.
            if !service.isActive { finishDictation() }
        }
    }

    /// The words stay where they were written, and the caret goes after them, ready to type on.
    private func finishDictation() {
        guard let end = ideaDraft.endDictation() else { return }
        selection = IdeaPromptDraft.selection(at: end, in: ideaDraft.text)
    }

    /// One way to the generation flow, the same as Generate › Prompt; it writes from the draft.
    private func submit() {
        guard canSubmit else { return }
        isSending = true
        isFocused = false
        presentation.present(.generateIdea)
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        IdeaComposerSheet(startsDictating: false)
    }
    .previewEnvironment(seeded: false)
}
#endif
