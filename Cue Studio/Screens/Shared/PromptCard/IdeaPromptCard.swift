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
    /// The first visit's card has no suggested idea: the board shows "Type or say an idea…" and the ideas list below it.
    var suggests = true
    /// Why Apple Intelligence can't write now; nil when it can. The arrow is off then (with an idea
    /// typed), and the note says why.
    var unavailableReason: String?

    @Environment(CreatorProfileService.self) private var profile
    @Environment(IdeaDraftService.self) private var ideaDraft
    @Environment(ScriptStarter.self) private var starter
    @Environment(DictationService.self) private var dictation
    @Environment(LanguageService.self) private var languages
    @Environment(PresentationService.self) private var presentation
    @Environment(SkyMemory.self) private var sky
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    @State private var selection: TextSelection?
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    /// Tapping the words while they are being dictated stops the dictation and takes the keyboard.
    @State private var focusesWhenDone = false
    /// The "Write in my voice" setup over the card, if it is open.
    @State private var voiceSetup: VoiceSetupSheet.Mode?
    /// The star of the idea being sent is still on its way: the arrow waits for it.
    @State private var isLaunching = false
    /// Where the arrow is on the screen: the star leaves from there.
    @State private var sendCenter = CGPoint.zero
    /// The height of a line of the field's text, which grows with Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var lineHeight = 21.0

    /// Lines of the field, fixed (the board clamps it to two): a longer idea scrolls inside it.
    private static let visibleLines = 2

    /// Nothing written, nothing suggested, not being written in: the card is the bare one of the first visit (the field has no box,
    /// the microphone is the yellow button).
    private var isBare: Bool {
        ideaDraft.isEmpty && suggestion == nil && !dictation.isActive && !isFocused && hasAI
    }

    /// Apple Intelligence can write: the card is the violet one and the arrow sends the idea.
    private var hasAI: Bool { unavailableReason == nil }

    /// The creator's own words are ready to send (not while they are still being dictated).
    private var hasTypedIdea: Bool {
        ideaDraft.canSubmit(isAvailable: true, isDictating: dictation.isActive)
    }

    /// The idea the card suggests while its field is empty ("↻ Another idea" brings the next).
    private var suggestion: String? {
        guard suggests, hasAI, ideaDraft.isEmpty, !dictation.isActive else { return nil }
        return ideaDraft.suggestion(for: profile.profile.niches)?.title
    }

    /// The arrow works with something to send: the typed idea or the suggestion. Without Apple Intelligence ("Write it")
    /// it needs the typed idea, which becomes the title of a blank draft.
    private var canSend: Bool {
        guard !isLaunching, !dictation.isActive else { return false }
        return hasAI ? (hasTypedIdea || suggestion != nil) : hasTypedIdea
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
        PromptCardSurface(animatesBackground: animates, isNeutral: !hasAI, showsScan: isFocused || dictation.isActive) {
            VStack(alignment: .leading, spacing: 10) {
                header
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
            .animation(.smooth(duration: 0.2), value: dictation.notice)
            .animation(.smooth(duration: 0.2), value: isBare)
        }
        .accessibilityElement(children: .contain)
        // Out here, not on the chip: the card's content is always dark, and its sheets follow the appearance.
        .sheet(item: $voiceSetup) { mode in
            if mode == .edit {
                // The voice is set up: the chip opens the full page (9.3), where every row has its own sheet.
                NavigationStack {
                    MyCueVoicePage()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { voiceSetup = nil }.accessibilityIdentifier("voicePage.done")
                            }
                        }
                }
            } else {
                // With an idea waiting on the card, the last question writes it: the script is the preview.
                VoiceSetupSheet(mode: mode, profile: profile.profile, ideaText: ideaDraft.submission) { writesScript in
                    if writesScript { starter.write() }
                }
            }
        }
        .onChange(of: ideaDraft.wantsFocus) { _, wants in
            guard wants else { return }
            ideaDraft.wantsFocus = false
            isFocused = true
        }
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

    /// "LET'S CUE!" in mono (yellow; violet-white on the bare card), and, while listening, the voice bars with "Listening…" at the end of
    /// the same line (the card keeps its height when the dictation starts and stops). With a suggestion, "↻ ANOTHER IDEA".
    private var header: some View {
        HStack {
            Text(verbatim: "LET'S CUE!")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.3)
                .foregroundStyle(hasAI && isBare ? Palette.aiTextStrong : Palette.accText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
        }
        .frame(minHeight: 14)
        .overlay(alignment: .trailing) {
            if dictation.isActive {
                DictationStatusRow(state: dictation.state, level: dictation.level)
            } else if suggestion != nil {
                anotherIdeaButton
            }
        }
        .animation(.smooth(duration: 0.2), value: dictation.isActive)
    }

    private var anotherIdeaButton: some View {
        Button {
            Haptics.selection()
            ideaDraft.anotherSuggestion()
        } label: {
            Text("↻ Another idea")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Palette.aiTextStrong.opacity(0.7))
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.vertical, -15)
        .accessibilityIdentifier("ideaCard.anotherIdea")
    }

    /// What the idea is for and how it is written, left to right as the board has them: the format, the platform and the voice. On
    /// the bare card they are 28 pt and the microphone is the yellow button at the end. Without Apple Intelligence there is no voice
    /// chip: nothing on the card is violet.
    private var chips: some View {
        HStack(alignment: .bottom, spacing: 6) {
            FlowLayout(spacing: 6) {
                if !isBare { formatChip }
                platformChip
                if hasAI { MyCueVoiceChip(setup: $voiceSetup, isCompact: isBare) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isBare { DictationButton(state: dictation.state, style: .primary, action: toggleDictation) }
        }
    }

    private var platformChip: some View {
        Button { presentation.present(.createFor) } label: {
            IdeaCardChip(label: String(localized: "For \(starter.platform.label)"), dotColor: starter.platform.tint, isCompact: isBare)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ideaCard.platformChip")
    }

    private var formatChip: some View {
        Button { presentation.present(.format) } label: {
            IdeaCardChip(
                label: ideaDraft.formatChoice == .auto ? String(localized: "Format") : ideaDraft.formatChoice.title,
                showsChevron: true, isTag: ideaDraft.formatChoice == .type(.ad) ? "AD" : nil, isCompact: isBare
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ideaCard.formatChip")
    }

    /// The idea in a dark glass box with the microphone and the arrow at its end (their places never move); on the bare card just the
    /// words, with no box.
    private var field: some View {
        HStack(alignment: .center, spacing: 8) {
            textArea
                .padding(.leading, isBare ? 0 : 14)
            if !isBare {
                DictationButton(state: dictation.state, style: .plain, action: toggleDictation)
                sendButton
            }
        }
        .padding(.trailing, isBare ? 0 : 6)
        .frame(minHeight: isBare ? 28 : 64)
        .background {
            if !isBare { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.heroChip) }
        }
    }

    /// The field to type in; while dictating, the same words read-only, which keeps the newest in
    /// view as they grow (a field that isn't being edited wouldn't scroll to them) and can still be
    /// scrolled to read earlier parts. Both have the same fixed height: two lines.
    private var textArea: some View {
        ZStack {
            if dictation.isActive {
                transcript
            } else {
                editor
            }
        }
        .frame(height: isBare ? 24 : lineHeight * CGFloat(Self.visibleLines) + 20)
    }

    private var editor: some View {
        // The suggestion is shown as the board shows it: white words over two lines (a text field's prompt keeps to one).
        ZStack(alignment: .topLeading) {
            if let suggestion {
                Text(suggestion)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.ink.opacity(0.9))
                    .lineLimit(Self.visibleLines)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            typingField
        }
    }

    private var typingField: some View {
        TextField(text: textBinding, selection: $selection, prompt: placeholder, axis: .vertical) {
            Text("Your idea")
        }
        .lineLimit(isBare ? 1...1 : Self.visibleLines...Self.visibleLines)
        .focused($isFocused)
        .font(.system(size: isBare ? 18 : 16, weight: .medium))
        .foregroundStyle(Palette.ink.opacity(0.9))
        .tint(Palette.acc)
        .padding(.vertical, isBare ? 0 : 10)
        .writingToolsBehavior(.limited)
        .accessibilityIdentifier("ideaCard.field")
    }

    private var transcript: some View {
        ScrollView {
            Group {
                if ideaDraft.text.isEmpty {
                    placeholder
                } else {
                    Text(ideaDraft.text).foregroundStyle(Palette.ink.opacity(0.9))
                }
            }
            .font(.system(size: 16, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
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

    /// The suggested idea while the field is empty (as the board shows it, in white); on the bare card "Type or say an idea…" in
    /// violet-white at 55%; without Apple Intelligence, what to do.
    private var placeholder: Text {
        if suggestion != nil { return Text(verbatim: "") }
        return Text(hasAI ? "Type or say an idea…" : "Type or say a title…").foregroundStyle(Palette.aiTextStrong.opacity(0.55))
    }

    /// The yellow arrow that sends the idea (40 pt); "Write it" when Apple Intelligence can't write.
    @ViewBuilder
    private var sendButton: some View {
        if hasAI {
            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.accInk)
                    .frame(width: 40, height: 40)
                    .background(Palette.acc.opacity(canSend ? 1 : 0.35), in: Circle())
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .onGeometryChange(for: CGPoint.self) { proxy in
                let frame = proxy.frame(in: .global)
                return CGPoint(x: frame.midX, y: frame.midY)
            } action: { sendCenter = $0 }
            .accessibilityLabel(Text("Generate script"))
            .accessibilityIdentifier("ideaCard.submit")
        } else {
            Button(action: submit) {
                Text("Write it")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canSend ? Palette.accInk : Palette.ink2)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(canSend ? Palette.acc : Palette.fill, in: Capsule())
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityIdentifier("ideaCard.submit")
        }
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

    /// Ends the editing and sends the idea: its star rises into the sky, then the script opens and Apple Intelligence
    /// writes it. The suggestion goes when the field is empty. Without Apple Intelligence the idea becomes the title of
    /// a blank draft.
    private func submit() {
        guard canSend else { return }
        isFocused = false
        guard hasAI else {
            starter.writeByHand()
            return
        }
        let idea = hasTypedIdea ? nil : suggestion
        isLaunching = true
        Task {
            await sky.launchStar(from: sendCenter, reduceMotion: reduceMotion)
            starter.write(idea: idea)
            if idea != nil { ideaDraft.anotherSuggestion() }
            isLaunching = false
        }
    }
}

#if DEBUG
#Preview {
    IdeaPromptCard()
        .padding()
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
