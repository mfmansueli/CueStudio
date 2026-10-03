//
//  IdeaPromptCard.swift
//  Cue Studio
//

import SwiftUI

/// The AI card on Scripts, the same one with and without scripts: "Let's Cue!", a one-line promise
/// ("Your idea, ready to record.") and a field for the idea, written or spoken right in the card. The field is three lines tall (it follows
/// Dynamic Type) and a longer idea scrolls inside it, so the card never grows with the text. The
/// microphone dictates into the field (speak, see the words, review, edit: it never sends anything
/// itself) and the arrow opens Generate with AI with the idea filled in, where platform, length and
/// voice are confirmed before anything is written. The text is the one draft kept by
/// `IdeaDraftService`, shared with Generate; "Write in my voice" (`WriteInMyVoiceRow`) shares its
/// state with Generate and Profile.
///
/// The card owns the microphone while it is on screen: it lets go when the app leaves the
/// foreground, when something else takes the screen (a sheet, the camera, another tab) and when the
/// card goes away, and the recognizer still finishes the last words into the draft.
struct IdeaPromptCard: View {
    var base: Color = Palette.surface
    var animatesBackground = true
    /// Why Apple Intelligence can't write now; nil when it can. The arrow is off then, and the note says why.
    var unavailableReason: String?
    let onSubmit: () -> Void

    @Environment(IdeaDraftService.self) private var ideaDraft
    @Environment(DictationService.self) private var dictation
    @Environment(LanguageService.self) private var languages
    @Environment(PresentationService.self) private var presentation
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isFocused: Bool
    @State private var selection: TextSelection?
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    /// Tapping the words while they are being dictated stops the dictation and takes the keyboard.
    @State private var focusesWhenDone = false
    /// The "Write in my voice" setup over the card, if it is open.
    @State private var voiceSetup: VoiceSetupSheet.Mode?
    /// The height of a line of the field's text, which grows with Dynamic Type.
    @ScaledMetric(relativeTo: .subheadline) private var lineHeight = 20.0

    /// Lines of the field, fixed: a longer idea scrolls inside it.
    private static let visibleLines = 3

    private var canSubmit: Bool {
        ideaDraft.canSubmit(isAvailable: unavailableReason == nil, isDictating: dictation.isActive)
    }

    /// Something else has the screen: the microphone is theirs.
    private var isCovered: Bool {
        presentation.sheet != nil || presentation.prompter != nil
            || presentation.showsRemoteController || presentation.selectedTab != .scripts
            || voiceSetup != nil
    }

    /// The light moves only while the card can be seen: not under its own setup sheet either.
    private var animates: Bool {
        animatesBackground && voiceSetup == nil
    }

    var body: some View {
        PromptCardSurface(base: base, animatesBackground: animates, usesAurora: true) {
            VStack(alignment: .leading, spacing: 12) {
                PromptCardHeader(title: "Let’s Cue!", animatesBackground: animates)
                intro
                field
                if let notice = dictation.notice, !dictation.isActive {
                    DictationNoticeView(notice: notice)
                        .transition(.opacity)
                }
                WriteInMyVoiceRow(setup: $voiceSetup)
                if let unavailableReason {
                    AIUnavailableNote(reason: unavailableReason)
                }
            }
            .animation(.smooth(duration: 0.2), value: dictation.notice)
        }
        .accessibilityElement(children: .contain)
        .onChange(of: dictation.state) { _, state in
            if state == .idle { finishDictation() }
            if state == .listening { AccessibilityNotification.Announcement(String(localized: "Listening…")).post() }
        }
        .onChange(of: ideaDraft.text) {
            // Editing is a fresh start: an old "didn't catch anything" is no longer news. While it
            // listens, the view follows the newest words.
            if !dictation.isActive, dictation.notice != nil { dictation.dismissNotice() }
            if dictation.isActive, followsEnd { scrollPosition.scrollTo(edge: .bottom) }
        }
        // Stopped and interrupted notes pass by themselves; the ones with something to do stay.
        .task(id: dictation.notice) {
            guard let notice = dictation.notice, notice == .interrupted || notice == .nothingHeard else { return }
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled, dictation.notice == notice { dictation.dismissNotice() }
        }
        // The app in the background (told, once): the microphone is let go and the words stay. Not on
        // `.inactive`: the system's microphone prompt makes the app inactive.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { dictation.interrupt() }
        }
        .onChange(of: isCovered) { _, covered in
            if covered { stopDictating() }
        }
        .onAppear {
            // A dictation that finished while the card was away leaves its segment behind.
            if !dictation.isActive { ideaDraft.endDictation() }
        }
        .onDisappear { stopDictating() }
    }

    // MARK: - Pieces

    /// The one-line description, or while dictating "Listening…" in its place. It fits one line at the
    /// default size and wraps at larger Dynamic Type sizes instead of being cut. It stays laid out
    /// (hidden) so the card keeps its height when the dictation starts and stops.
    private var intro: some View {
        Text("Your idea, ready to record.")
            .font(.subheadline)
            .foregroundStyle(Palette.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(dictation.isActive ? 0 : 1)
            .accessibilityHidden(dictation.isActive)
            .overlay(alignment: .topLeading) {
                if dictation.isActive {
                    DictationStatusRow(state: dictation.state, level: dictation.level)
                }
            }
            .animation(.smooth(duration: 0.2), value: dictation.isActive)
    }

    /// The text, with the microphone and the arrow at its end. Their places never move.
    private var field: some View {
        HStack(alignment: .bottom, spacing: 0) {
            textArea
                .padding(.leading, 16)
            DictationButton(state: dictation.state, action: toggleDictation)
            sendButton
        }
        .padding(.trailing, 1)
        .background(Palette.insetField, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    /// The field to type in; while dictating, the same words read-only, which keeps the newest in
    /// view as they grow (a field that isn't being edited wouldn't scroll to them) and can still be
    /// scrolled to read earlier parts. Both have the same fixed height.
    private var textArea: some View {
        ZStack {
            if dictation.isActive {
                transcript
            } else {
                editor
            }
        }
        .frame(height: lineHeight * CGFloat(Self.visibleLines) + 24)
    }

    private var editor: some View {
        TextField(text: textBinding, selection: $selection, prompt: placeholder, axis: .vertical) {
            Text("Your idea")
        }
        .lineLimit(Self.visibleLines...Self.visibleLines)
        .focused($isFocused)
        .font(.subheadline)
        .foregroundStyle(Palette.ink)
        .tint(Palette.accText)
        .padding(.vertical, 12)
        .writingToolsBehavior(.limited)
        .accessibilityIdentifier("ideaCard.field")
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
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        }
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(followsEnd ? .bottom : .top)
        .contentShape(Rectangle())
        .onTapGesture {
            focusesWhenDone = true
            dictation.stop()
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Tap to stop and edit."))
        .accessibilityIdentifier("ideaCard.transcript")
    }

    private var placeholder: Text {
        Text("Speak or type your idea…").foregroundStyle(Palette.ink2)
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
        .accessibilityIdentifier("ideaCard.submit")
    }

    private var textBinding: Binding<String> {
        Binding(get: { ideaDraft.text }, set: { ideaDraft.text = $0 })
    }

    /// While the words are added at the end, the view follows them; in the middle of a text it stays put.
    private var followsEnd: Bool {
        ideaDraft.draft.dictation?.after.isEmpty != false
    }

    // MARK: - Actions

    /// The microphone starts the dictation, or stops it (also while it is still getting ready).
    private func toggleDictation() {
        Haptics.selection()
        if dictation.isActive {
            dictation.stop()
        } else {
            startDictation()
        }
    }

    /// Dictation writes at the caret (the end when the field has none), after what is there and never
    /// over it. The keyboard goes down so the words have room.
    private func startDictation() {
        guard dictation.state == .idle else { return }
        ideaDraft.beginDictation(caret: IdeaPromptDraft.caretOffset(of: selection, in: ideaDraft.text))
        isFocused = false
        let request = languages.dictationRequest(existingText: ideaDraft.text)
        // The words go to the draft itself, not through this view: they may arrive after it is gone.
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
        if let end = ideaDraft.endDictation() {
            selection = IdeaPromptDraft.selection(at: end, in: ideaDraft.text)
        }
        if focusesWhenDone {
            focusesWhenDone = false
            isFocused = true
        }
    }

    private func stopDictating() {
        if dictation.isActive { dictation.stop() }
    }

    /// Ends the editing and opens Generate with AI with this idea; nothing is written yet.
    private func submit() {
        guard canSubmit else { return }
        isFocused = false
        onSubmit()
    }
}

#if DEBUG
#Preview {
    IdeaPromptCard(onSubmit: {})
        .padding()
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
