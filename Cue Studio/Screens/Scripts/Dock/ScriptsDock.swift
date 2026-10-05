//
//  ScriptsDock.swift
//  Cue Studio
//

import SwiftUI

/// The Scripts AI dock (v30 · 3.1, 3.2): clean glass fixed above the tab bar. Row 1 is the choices for the idea (Format, the platform and
/// the voice); row 2 is the idea itself (two lines, the suggested idea while it is empty), "↻ another idea", the microphone and the
/// yellow arrow. Scrolling the list down folds row 1 away (09 §6); focusing the field raises the dock with the keyboard.
///
/// The text is the one draft kept by `IdeaDraftService`. The microphone dictates into the field (speak, see the words, review,
/// edit: it never sends anything itself). The dock owns the microphone while it is on screen: it lets go when the app leaves the
/// foreground, when something else takes the screen (a sheet, the camera, another tab) and when the dock goes away, and the
/// recognizer still finishes the last words into the draft.
struct ScriptsDock: View {
    /// The first visit's dock has no Format chip (03 · 3.1).
    var showsFormat = true
    /// Row 1 folds away while the list scrolls down.
    var isFolded = false
    /// The field has the keyboard (or is being dictated into): the list behind dims.
    @Binding var isEditing: Bool
    /// Why Apple Intelligence can't write now; nil when it can. The arrow says "Write it" then.
    var unavailableReason: String?

    @Environment(CreatorProfileService.self) private var profile
    @Environment(IdeaDraftService.self) private var ideaDraft
    @Environment(ScriptStarter.self) private var starter
    @Environment(DictationService.self) private var dictation
    @Environment(LanguageService.self) private var languages
    @Environment(PresentationService.self) private var presentation
    @Environment(IdeaTransitionService.self) private var transition
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    @State private var selection: TextSelection?
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    /// Tapping the words while they are being dictated stops the dictation and takes the keyboard.
    @State private var focusesWhenDone = false
    /// The My Cue Voice setup over the dock, if it is open.
    @State private var voiceSetup: VoiceSetupSheet.Mode?
    /// Where the arrow is on the screen: the star leaves from there.
    @State private var sendCenter = CGPoint.zero
    /// The height of a line of the field's text, which grows with Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var lineHeight = 21.0

    /// Lines of the field (the board clamps it to two): a longer idea scrolls inside it.
    private static let visibleLines = 2
    /// Row 1: 30 pt chips with a 36 pt touch area.
    private static let topRowHeight: CGFloat = 36
    private static let rowSpacing: CGFloat = 10
    /// How much shorter the dock is with row 1 folded away.
    static let foldHeight = topRowHeight + rowSpacing

    /// Apple Intelligence can write: the arrow sends the idea.
    private var hasAI: Bool { unavailableReason == nil }

    /// The creator's own words are ready to send (not while they are still being dictated).
    private var hasTypedIdea: Bool {
        ideaDraft.canSubmit(isAvailable: true, isDictating: dictation.isActive)
    }

    /// The idea the dock suggests while its field is empty ("↻" brings the next).
    private var suggestion: String? {
        guard hasAI, ideaDraft.isEmpty, !dictation.isActive else { return nil }
        return ideaDraft.suggestion(for: profile.profile.niches)?.title
    }

    /// The arrow works with something to send: the typed idea or the suggestion. Without Apple Intelligence ("Write it")
    /// it needs the typed idea, which becomes the title of a blank draft.
    private var canSend: Bool {
        guard !transition.isActive, !dictation.isActive else { return false }
        return hasAI ? (hasTypedIdea || suggestion != nil) : hasTypedIdea
    }

    /// Something else has the screen: the microphone is theirs.
    private var isCovered: Bool {
        presentation.sheet != nil || presentation.prompter != nil
            || presentation.showsRemoteController || presentation.selectedTab != .scripts
            || voiceSetup != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The fold is animated by whoever folds it (`ScriptsView`), so the glass moves with the row. The chips stay where they are
            // while the glass closes over them, and fade a little sooner. The row takes its spacing with it (`foldHeight` in all).
            topRow
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2)) { $0.opacity(isFolded ? 0 : 1) }
                .frame(height: isFolded ? 0 : Self.topRowHeight, alignment: .bottom)
                .clipped()
                .padding(.bottom, isFolded ? 0 : Self.rowSpacing)
                .accessibilityHidden(isFolded)
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                if let notice = dictation.notice, !dictation.isActive {
                    DictationNoticeView(notice: notice)
                        .transition(.opacity)
                }
                field
                if let unavailableReason {
                    AIUnavailableNote(reason: unavailableReason)
                }
            }
        }
        .padding(EdgeInsets(top: 16, leading: 12, bottom: 12, trailing: 12))
        .dockSurface()
        .animation(.smooth(duration: 0.2), value: dictation.notice)
        .accessibilityElement(children: .contain)
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
                // With an idea waiting in the dock, the last question writes it: the script is the preview.
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
        .onChange(of: isFocused) { _, _ in isEditing = isFocused || dictation.isActive }
        .onChange(of: dictation.state) { _, state in
            isEditing = isFocused || dictation.isActive
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
            // A dictation that finished while the dock was away leaves its segment behind.
            if !dictation.isActive { ideaDraft.endDictation() }
        }
        .onDisappear {
            stopDictating()
            isEditing = false
        }
    }

    // MARK: - Row 1

    /// The choices for the idea, left to right as the board has them: the format, the platform and the voice. While it listens the
    /// row says so instead (the dock keeps its height when the dictation starts and stops). Without Apple Intelligence there is no
    /// voice chip: nothing in the dock is violet.
    @ViewBuilder
    private var topRow: some View {
        if dictation.isActive {
            DictationStatusRow(state: dictation.state, level: dictation.level)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    if showsFormat { formatChip }
                    platformChip
                    if hasAI { MyCueVoiceChip(setup: $voiceSetup, hitHeight: Self.topRowHeight) }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private var platformChip: some View {
        Button { presentation.present(.createFor) } label: {
            IdeaCardChip(label: String(localized: "For \(starter.platform.label)"), dotColor: starter.platform.tint, hitHeight: Self.topRowHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Platform, \(starter.platform.label)"))
        .accessibilityIdentifier("ideaCard.platformChip")
    }

    private var formatChip: some View {
        Button { presentation.present(.format) } label: {
            IdeaCardChip(
                label: ideaDraft.formatChoice == .auto ? String(localized: "Format") : ideaDraft.formatChoice.title,
                showsChevron: true, isTag: ideaDraft.formatChoice == .type(.ad) ? "AD" : nil, hitHeight: Self.topRowHeight
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Format, \(ideaDraft.formatChoice == .auto ? String(localized: "Auto") : ideaDraft.formatChoice.title)"))
        .accessibilityIdentifier("ideaCard.formatChip")
    }

    // MARK: - Row 2

    /// The idea in a dark box with "another idea", the microphone and the arrow at its end (their places never move).
    private var field: some View {
        HStack(alignment: .center, spacing: 6) {
            textArea
                .padding(.leading, 14)
            if suggestion != nil { anotherIdeaButton }
            DictationButton(state: dictation.state, style: .plain, action: toggleDictation)
            sendButton
        }
        .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 6))
        .frame(minHeight: 56)
        .background(Palette.dockField, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// The field to type in; while dictating, the same words read-only, which keeps the newest in view as they grow (a field that
    /// isn't being edited wouldn't scroll to them) and can still be scrolled to read earlier parts. Both have the same fixed height.
    private var textArea: some View {
        ZStack {
            if dictation.isActive {
                transcript
            } else {
                editor
            }
        }
        .frame(height: lineHeight * CGFloat(Self.visibleLines) + 12)
    }

    private var editor: some View {
        // The suggestion is shown as the board shows it: white words over two lines (a text field's prompt keeps to one).
        ZStack(alignment: .topLeading) {
            if let suggestion {
                Text(suggestion)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(Self.visibleLines)
                    .padding(.vertical, 6)
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
        .lineLimit(Self.visibleLines...Self.visibleLines)
        .focused($isFocused)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Palette.ink)
        .tint(Palette.acc)
        .padding(.vertical, 6)
        .writingToolsBehavior(.limited)
        .accessibilityHint(Text("Say or type an idea"))
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
            .font(.system(size: 16, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
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

    /// Shown while the field is empty and nothing is suggested (no Apple Intelligence, or while it listens): what to do.
    private var placeholder: Text {
        if suggestion != nil { return Text(verbatim: "") }
        return Text(hasAI ? "Say it or type your idea…" : "Type or say a title…").foregroundStyle(Palette.ink.opacity(0.55))
    }

    private var anotherIdeaButton: some View {
        Button {
            Haptics.selection()
            ideaDraft.anotherSuggestion()
        } label: {
            Text(verbatim: "↻")
                .font(.system(size: 17))
                .foregroundStyle(Palette.aiTextStrong.opacity(0.75))
                .frame(width: 32, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Another idea"))
        .accessibilityIdentifier("ideaCard.anotherIdea")
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
            .accessibilityLabel(Text("Write it"))
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

    /// Ends the editing and sends the idea: its star rises from the arrow and is the transition into the script, where Apple Intelligence
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
        Haptics.medium()
        starter.write(idea: idea, from: sendCenter)
        if idea != nil { ideaDraft.anotherSuggestion() }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var editing = false
    ScriptsDock(isEditing: $editing)
        .padding()
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
