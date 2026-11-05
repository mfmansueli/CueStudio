//
//  LogbookView.swift
//  Cue Studio
//

import os
import SwiftUI

/// The Logbook: "Catch it now. Write it later." under the system's large title. Its ideas fill the page, grouped by day (`LogbookDays`),
/// and with none yet the empty state sits in its middle. At its foot, as in Messages, one field catches the next idea: type it, or hold
/// the yellow button at the field's end and say it (its words arrive in the field, after anything typed there, and letting go saves them;
/// or tap it once to start and again to finish); with words typed, the button is the arrow that saves them. Each idea waits as a card with
/// "✦ Write", which turns it into a script on the script page (Shape is only for adding cues). Without Apple Intelligence the card says
/// "Write it" and opens a blank draft titled with the idea. Speaking is on-device recognition: only the words are kept, never the sound.
/// Swipe an idea to delete it (or hold it), or Select (beside the first day, as on Scripts) to pick several and delete them together; a
/// deletion has Undo for 4 s, shown in the sheet, and is then for good.
struct LogbookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LogbookService.self) private var logbook
    @Environment(DictationService.self) private var dictation
    @Environment(LanguageService.self) private var languages
    @Environment(TopicTaggingService.self) private var tagging
    @Environment(ScriptStarter.self) private var starter
    @Environment(AIStatus.self) private var aiStatus
    @Environment(PresentationService.self) private var presentation
    @Environment(ToastService.self) private var toast
    /// The note a notification was about: brought into view and outlined in yellow.
    @State private var focused: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var typed = ""
    /// What was in the field when the hold began: the heard words go after it.
    @State private var typedBeforeHold = ""
    /// The words heard so far while it listens, shown by the caption over the field (`LogbookLiveCaption`), not in it: the field keeps its
    /// line and the button its place.
    @State private var heard = ""
    @State private var isHolding = false
    /// A tap, not a hold: the capture goes on after the finger is lifted, until the button is tapped again.
    @State private var isLocked = false
    /// The microphone is being asked for: it can't be told yet whether anything will listen.
    @State private var isStarting = false
    @State private var pressedAt: Date?
    @State private var heldSince: Date?
    /// An idea just saved with Return: brought into view above the keyboard, which stays up for the next one.
    @State private var justSaved: UUID?
    /// The idea just saved, outlined for a moment as it lands at the top of the list.
    @State private var highlighted: UUID?
    /// The microphone sinks for a moment under the finger.
    @State private var isPressed = false
    /// Goes up as listening starts: the microphone jumps once.
    @State private var listenTurn = 0
    /// Goes up once as the Logbook opens: the microphone breathes once, to say where to tap.
    @State private var inviteTurn = 0
    /// The idea whose ✦ Write was tapped: its card lights in violet for a moment before the star leaves.
    @State private var writingID: UUID?
    /// Where each card's Write button is on the screen: the star leaves from there.
    @State private var writeCenters: [UUID: CGPoint] = [:]
    /// Select is on: a tap picks an idea, and the field gives its place to the bar that deletes what is picked.
    @State private var isSelecting = false
    @State private var selection = Set<UUID>()
    /// Ideas tapped open to their whole text (a card shows three lines); a spoken one lands open, to read what was heard.
    @State private var expanded = Set<UUID>()
    /// The idea being corrected in the field (Edit, on holding its card), and what the field held before, back once it is done.
    @State private var editing: UUID?
    @State private var draftBeforeEdit = ""
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                // The ideas are a list, so one can be swiped away the system's way.
                List {
                    ForEach(Array(LogbookDays.days(of: logbook.waiting).enumerated()), id: \.element.id) { index, day in
                        dayHeader(day.title, showsSelect: index == 0)
                        ForEach(day.entries) { entry in
                            entryRow(entry)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 6, trailing: Metrics.gutter))
                                // Delete at the edge (a full swipe deletes), Edit beside it in the system's grey (owner, 05/11/2026).
                                // No menu on holding the card: its lifted copy fought the card opening under a tap.
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if !isSelecting {
                                        Button(role: .destructive) { delete(entry) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        Button { startEdit(entry) } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.gray)
                                        .accessibilityIdentifier("logbook.edit")
                                    }
                                }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // The keyboard goes with a tap anywhere on the page, not with a swipe: a swipe down that took the keyboard went on to take
                // the sheet with it (the owner, 30/10/2026).
                .scrollDismissesKeyboard(.never)
                // With no idea yet, the empty state in the middle of the room the list has (above the keyboard while typing).
                .overlay {
                    if logbook.waiting.isEmpty {
                        emptyState.transition(.opacity)
                    }
                }
                // Only while typing: on, it takes the tap a swiped idea's Delete needs.
                .simultaneousGesture(TapGesture().onEnded { typing = false }, isEnabled: typing)
                .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: logbook.waiting.isEmpty)
                .task {
                    guard let id = presentation.logbookFocus else { return }
                    presentation.logbookFocus = nil
                    focused = id
                    proxy.scrollTo(id, anchor: .center)
                }
                .onChange(of: justSaved) { _, id in
                    guard let id else { return }
                    justSaved = nil
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { proxy.scrollTo(id, anchor: .top) }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isSelecting {
                    SelectionBar(
                        count: selection.count, prompt: String(localized: "Select ideas"),
                        allSelected: !logbook.waiting.isEmpty && logbook.waiting.allSatisfy { selection.contains($0.id) },
                        onSelectAll: toggleSelectAll, onDelete: deleteSelection,
                        deleteIdentifier: "logbook.deleteSelectionButton", selectAllIdentifier: "logbook.selectAllButton"
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    composer
                        // The field and its button keep their size past the first accessibility size (the field grows by its lines).
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: isSelecting)
            .background(Palette.bg)
            .navigationTitle("Logbook")
            .navigationSubtitle("Catch it now. Write it later.")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // While selecting, Done beside the first day ends the selection: one Done on screen at a time.
                if !isSelecting {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .accessibilityIdentifier("logbook.doneButton")
                    }
                }
            }
        }
        // A deletion's Undo shows here, in front of the sheet, not under it.
        .toastHost(inSheet: true)
        // While typing or listening, a swipe down doesn't close the sheet with the idea half caught: a tap on the page puts the keyboard
        // away first, the button ends the listening.
        .interactiveDismissDisabled(typing || isHolding)
        .onChange(of: logbook.waiting.isEmpty) { _, empty in
            if empty { isSelecting = false }
        }
        .onChange(of: isSelecting) { _, selecting in
            if selecting {
                typing = false
                cancelEdit()
            } else {
                selection.removeAll()
            }
        }
        .onChange(of: dictation.state) { _, state in
            // Ended, by the creator or on its own (a call, the microphone gone): what was heard is saved and the button rests, even
            // under a finger still down.
            if state == .idle, heldSince != nil {
                endListening()
                finishCapture()
            }
        }
        .onChange(of: status) { old, new in
            // VoiceOver hears the line too; a download's percentage only once.
            guard let new, !(old?.isDownloading == true && new.isDownloading) else { return }
            AccessibilityNotification.Announcement(new.message).post()
        }
        .onAppear {
            // What was left in the field last time is there again; an old "Didn't catch anything" from elsewhere is not.
            if typed.isEmpty { typed = logbook.draft }
            if !dictation.isActive { dictation.dismissNotice() }
        }
        .onDisappear {
            logbook.keepDraft(unsentWords)
            isLocked = false
            dictation.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { logbook.keepDraft(unsentWords) }
        }
        .task {
            // Once, as it opens: the microphone breathes, to say where to tap.
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .milliseconds(350))
            inviteTurn += 1
        }
        .onChange(of: hasWords) { _, now in
            // The button turns into the arrow that saves, under the creator's fingers: felt as well as seen (not as a draft comes back).
            if now, typing, !isHolding { Haptics.selection() }
        }
        .accessibilityIdentifier("logbook.sheet")
    }

    // MARK: - Parts

    /// The page's foot: one glass field to type an idea in, the button at its end to say it (or, with words typed, to save them), and over
    /// them, while it listens or can't, one line saying so (with Open Settings when the microphone is off for Cue).
    private var composer: some View {
        VStack(spacing: 8) {
            if let status {
                VStack(spacing: 2) {
                    Text(status.message)
                        .cueFont(.footnote, weight: .semibold)
                        .foregroundStyle(status.isWarning ? Palette.warnText : Palette.ink2)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(status.identifier)
                    if status.offersSettings {
                        Button("Open Settings") { openURL.openAppSettings() }
                            .cueFont(.footnote, weight: .semibold)
                            .foregroundStyle(Palette.accText)
                            .frame(minHeight: Metrics.hitTarget)
                            .accessibilityIdentifier("logbook.openSettings")
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }
            if editing != nil { editHeader }
            // The button stays in the middle of the field's end as the field grows with typed words; while it listens the field keeps its
            // one line (`LogbookLiveCaption`), so nothing moves under the finger (owner, 05/11/2026).
            HStack(alignment: .center, spacing: 8) {
                // The prompt is drawn by the page, in `ink2` (the system's grey is about 2.4:1 on the glass), and on as many lines as it
                // needs (a field's own prompt keeps to one line and cuts it); short, so it is one line on the smallest iPhone in most languages.
                ZStack(alignment: .topLeading) {
                    if typed.isEmpty, !isHolding {
                        Text("Type, or hold to talk")
                            .cueFont(17)
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                TextField(text: $typed, prompt: Text(verbatim: ""), axis: .vertical) {
                    Text("Type, or hold to talk")
                }
                    .lineLimit(1...4)
                    .cueFont(17)
                    .tint(Palette.accText)
                    .focused($typing)
                    .submitLabel(.done)
                    .onSubmit(addTyped)
                    // The field grows to show a long idea, and Return still saves it (in a field that grows it would start a new line); pasted
                    // lines stay, as one paragraph (`LogbookComposerInput`).
                    .onChange(of: typed) { old, new in
                        guard !isHolding else { return }
                        // The creator typing again: the line about the last capture has said its part.
                        if typing, !new.isEmpty, dictation.notice != nil, !dictation.isActive { dictation.dismissNotice() }
                        switch LogbookComposerInput.change(from: old, to: new) {
                        case .keep: break
                        case .replace(let words): typed = words
                        case .save(let words):
                            typed = words
                            addTyped()
                        }
                    }
                    .accessibilityIdentifier("logbook.field")
                    // While it listens the heard words run over the empty field, never sizing it: the field keeps its line.
                    .overlay(alignment: .leading) {
                        if isHolding {
                            LogbookLiveCaption(text: heard)
                                .transition(.opacity)
                        }
                    }
                }
                    .padding(.leading, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
                captureButton
            }
            .padding(6)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isListening || typing ? Palette.accLine : .clear, lineWidth: 1)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: status)
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 8)
    }

    /// Over the field while an idea is corrected in it: what it is doing, and the way out.
    private var editHeader: some View {
        HStack(spacing: 8) {
            Label("Editing idea", systemImage: "pencil")
                .cueFont(.footnote, weight: .semibold)
                .foregroundStyle(Palette.ink2)
            Spacer(minLength: 8)
            Button("Cancel", action: cancelEdit)
                .cueFont(.footnote, weight: .semibold)
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("logbook.cancelEdit")
        }
        .padding(.horizontal, 8)
        .padding(.bottom, -8)
        .transition(.opacity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("logbook.editing")
    }

    /// The field's words that aren't an idea yet: kept for the next visit. An edit left half done is not one (its idea is still there).
    private var unsentWords: String { editing == nil ? Self.joined(typed, heard) : draftBeforeEdit }

    /// What was typed, then what was heard after it.
    private static func joined(_ typed: String, _ heard: String) -> String {
        [typed.trimmingCharacters(in: .whitespacesAndNewlines), heard.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// What the line over the field says: listening, how to finish, the model downloading, or why nothing can listen. Nothing otherwise
    /// (the field's prompt says how).
    private var status: LogbookComposerStatus? {
        .current(isHolding: isHolding, isLocked: isLocked, isStarting: isStarting, state: dictation.state, notice: dictation.notice)
    }

    /// The button grows with its rings only while something is (about to be) listening: a hold where the microphone is off says why instead.
    private var isListening: Bool { status?.isListening == true }

    /// There are words in the field to save.
    private var hasWords: Bool { !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The yellow button at the field's end. With words typed it is the arrow that saves them (where to confirm is never in doubt);
    /// otherwise hold it to talk, or tap it to start and again to finish: it grows and its rings follow the voice while it listens.
    @ViewBuilder
    private var captureButton: some View {
        if hasWords, !isHolding {
            Button(action: addTyped) {
                captureFace(saves: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(editing == nil ? Text("Save to Logbook") : Text("Save"))
            .accessibilityIdentifier("logbook.save")
        } else {
            captureFace(saves: false)
                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 80, pressing: { pressing in
                    pressing ? press() : release()
                }, perform: {})
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Capture an idea by voice"))
                .accessibilityHint(Text("Double tap to start, double tap again to finish"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: Text("Start or stop")) { isHolding ? stopCapture() : beginCapture() }
                .accessibilityIdentifier("logbook.captureButton")
        }
    }

    /// The button's yellow circle round its microphone (the arrow, when it `saves`): it breathes once as the page opens, sinks under the
    /// finger, grows while it listens (rings leaving it, further with a louder voice, `LogbookRipples`) and its icon jumps as listening starts.
    private func captureFace(saves: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Palette.acc)
                .scaleEffect((isListening ? 1.12 : 1) * (isPressed ? 0.9 : 1))
                .shadow(color: Palette.acc.opacity(isListening ? 0.6 : 0.25), radius: isListening ? 16 : 8)
                .keyframeAnimator(initialValue: 1.0, trigger: inviteTurn) { circle, scale in
                    circle.scaleEffect(scale)
                } keyframes: { _ in
                    CubicKeyframe(1.12, duration: 0.35)
                    SpringKeyframe(1.0, duration: 0.6, spring: .bouncy)
                }
            Group {
                if saves {
                    Image(systemName: "arrow.up").cueFont(19, weight: .bold)
                } else {
                    CueIconView(.dictate, size: 22)
                }
            }
                .foregroundStyle(Palette.accInk)
                .contentTransition(.symbolEffect(.replace))
                .keyframeAnimator(initialValue: 1.0, trigger: listenTurn) { icon, scale in
                    icon.scaleEffect(scale)
                } keyframes: { _ in
                    CubicKeyframe(1.25, duration: 0.12)
                    SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
                }
        }
        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
        .overlay {
            // The rings spread past the button, over the field's edge: drawn on top, they move nothing.
            if isListening {
                LogbookRipples(level: dictation.level, radius: 25)
                    .frame(width: 140, height: 140)
                    .transition(.opacity)
            }
        }
        .contentShape(Circle())
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isListening)
        .animation(isPressed ? CueMotion.pressIn : CueMotion.pressRelease, value: isPressed)
    }

    /// "TODAY", "YESTERDAY", "MONDAY"…: a day's ideas start under it. The first one ends with Select (Done while selecting), as Scripts' first group.
    private func dayHeader(_ title: String, showsSelect: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(verbatim: title)
                .hudFont()
                .interfaceTracking(1.2)
                .foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("logbook.day")
            Spacer()
            if showsSelect {
                Button(isSelecting ? "Done" : "Select") { isSelecting.toggle() }
                    .monoFont(size: 10, weight: .semibold)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Palette.ink2)
                    .frame(minHeight: Metrics.hitTarget)
                    .padding(.vertical, -16)
                    .accessibilityIdentifier("logbook.selectButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: Metrics.gutter, bottom: 2, trailing: Metrics.gutter))
    }

    /// An idea's card: while selecting, the whole card picks it (its mark where ✦ Write was); otherwise held, it offers Delete.
    @ViewBuilder
    private func entryRow(_ entry: LogbookEntry) -> some View {
        if isSelecting {
            let isSelected = selection.contains(entry.id)
            Button {
                Haptics.selection()
                if selection.remove(entry.id) == nil { selection.insert(entry.id) }
            } label: {
                card(entry).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("logbook.entry")
        } else {
            card(entry)
                // A tap shows the whole idea (a card keeps to three lines), and another folds it.
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                        if expanded.remove(entry.id) == nil { expanded.insert(entry.id) }
                    }
                }
        }
    }

    /// The empty state (E): the mark, what this is for and how to start, in the middle of the page; the field below is its action.
    /// Above the keyboard of a small iPhone the mark gives way, so the words never run under the title.
    private var emptyState: some View {
        ViewThatFits(in: .vertical) {
            emptyStateWords(withMark: true)
            emptyStateWords(withMark: false)
        }
        .padding(.horizontal, Metrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("logbook.empty")
    }

    private func emptyStateWords(withMark: Bool) -> some View {
        VStack(spacing: 14) {
            if withMark { EmptyStateMark(icon: .book) }
            Text("Your Logbook is empty")
                .cueFont(22, weight: .bold).tracking(-0.44).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Hold the mic to catch an idea. Write it later.")
                .cueFont(15).foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// An idea's card: its words the whole width (three lines, or all of them once tapped), and under them one line saying how and when it
    /// came in, with ✦ Write at its end (owner, 05/11/2026: the button at the side took the words' room). While selecting, the mark at the end.
    private func card(_ entry: LogbookEntry) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.text)
                    .cueFont(16, weight: .medium)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(expanded.contains(entry.id) ? nil : 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    entryMeta(entry)
                    Spacer(minLength: 4)
                    if !isSelecting { writeButton(entry) }
                }
            }
            if isSelecting {
                ScriptSelectionMark(isSelected: selection.contains(entry.id))
                    .frame(width: 44, height: 40)
            }
        }
        .padding(14)
        .background(Palette.surface, in: shape)
        .overlay {
            if focused == entry.id || highlighted == entry.id || editing == entry.id {
                shape.strokeBorder(Palette.acc, lineWidth: 1.5)
                    .shadow(color: Palette.acc.opacity(highlighted == entry.id ? 0.4 : 0), radius: 14)
                    .transition(.opacity)
            }
        }
        .overlay {
            // ✦ Write tapped: the card lights in the AI's violet for a moment before the star leaves its button.
            if writingID == entry.id {
                shape.strokeBorder(Palette.aiText, lineWidth: 1.5)
                    .shadow(color: Palette.aiText.opacity(0.6), radius: 16)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.6), value: highlighted)
        .animation(.easeOut(duration: 0.2), value: writingID)
        .cardDepth(shape)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("logbook.entry")
    }

    /// "🎙 SPOKEN · 0:06 · 2 HR. AGO" (the microphone yellow) or "✎ TYPED · NOW", and the topic's dot. "NOW" becomes "1 MIN. AGO" while the
    /// sheet stays open.
    private func entryMeta(_ entry: LogbookEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: entry.isSpoken ? "mic.fill" : "pencil")
                .font(.fixed(11, weight: .semibold))
                .foregroundStyle(entry.isSpoken ? Palette.accText : Palette.ink2)
                .accessibilityHidden(true)
            TimelineView(.everyMinute) { context in
                Text(verbatim: LogbookDays.meta(for: entry, now: context.date)).hudFont().interfaceTracking(0.8).foregroundStyle(Palette.ink2)
            }
            if let color = color(for: entry) {
                Circle().fill(color).frame(width: 8, height: 8).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
            }
        }
    }

    /// ✦ Write, small at the end of the card's last line; its touch is the full 44 pt (without Apple Intelligence, "Write it").
    private func writeButton(_ entry: LogbookEntry) -> some View {
        Button { writeIdea(entry) } label: {
            HStack(spacing: 4) {
                if aiStatus.isAvailable { Text(verbatim: "✦") }
                Text(aiStatus.isAvailable ? "Write" : "Write it")
            }
            .cueFont(14, weight: .semibold)
            .foregroundStyle(aiStatus.isAvailable ? Palette.aiTextStrong : Palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(aiStatus.isAvailable ? Palette.aiFill : Palette.fill, in: Capsule())
            .overlay { if aiStatus.isAvailable { Capsule().strokeBorder(Palette.aiBorder, lineWidth: 0.5) } }
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .padding(.vertical, -7)
        .onGeometryChange(for: CGPoint.self) { proxy in
            let frame = proxy.frame(in: .global)
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { writeCenters[entry.id] = $0 }
        .accessibilityIdentifier("logbook.write")
    }

    private func color(for entry: LogbookEntry) -> Color? {
        guard let id = entry.topic, let index = tagging.topics.firstIndex(where: { $0.id == id }) else { return nil }
        return OnboardingTopic.color(at: index)
    }

    // MARK: - Capturing

    /// A finger down starts listening, unless a tap left it going: that finger is the one that ends it.
    private func press() {
        pressedAt = .now
        // The circle sinks under the finger and springs back, like a key.
        isPressed = true
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            isPressed = false
        }
        guard !isHolding else { return }
        beginCapture()
    }

    /// A finger up ends what it started. A tap (a touch too short to have said anything) is a start instead: it keeps listening until the next tap.
    private func release() {
        let held = pressedAt.map { Date.now.timeIntervalSince($0) } ?? .infinity
        pressedAt = nil
        guard isHolding else { return }
        if isLocked {
            stopCapture()
        } else if held < Self.tapLimit {
            // A tap where nothing can listen (no speech recognition, no permission) has nothing to keep going.
            guard dictation.state != .idle || isStarting else { return stopCapture() }
            isLocked = true
            Haptics.selection()
        } else {
            endCapture()
        }
    }

    /// The start of listening is an animation interval (`studio.cue` / Motion): Instruments and `PerformanceDeviceUITests` count its
    /// hitches.
    private static let signposter = OSSignposter(subsystem: "studio.cue", category: "Motion")

    private static func markMotion(_ name: StaticString, seconds: Double) {
        let interval = signposter.beginAnimationInterval(name, id: signposter.makeSignpostID())
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            signposter.endInterval(name, interval)
        }
    }

    /// Shorter than this, a touch is a tap.
    private static let tapLimit: TimeInterval = 0.35

    private func beginCapture() {
        guard !isHolding, dictation.state == .idle else { return }
        isHolding = true
        // The keyboard stays while the finger holds: put away now, it would carry the mic down from under the finger (owner, 30/10/2026).
        typedBeforeHold = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        heard = ""
        heldSince = .now
        HapticPatterns.playListen()
        Self.markMotion("Logbook listen", seconds: 0.8)
        listenTurn += 1
        let request = languages.dictationRequest(existingText: typedBeforeHold)
        isStarting = true
        Task {
            await dictation.start(language: request) { words in heard = words }
            isStarting = false
            // It never reached the microphone (no speech recognition here, no permission): the line says why at once, even with the
            // finger still down, and the button rests. Nothing to keep listening for.
            guard dictation.state == .idle, isHolding else { return }
            endListening()
            finishCapture()
        }
    }

    /// The button rests: no hold, no tap waiting to finish, the keyboard down (the speech that held it is over).
    private func endListening() {
        isLocked = false
        isHolding = false
        typing = false
    }

    private func stopCapture() {
        isLocked = false
        endCapture()
    }

    private func endCapture() {
        guard isHolding else { return }
        isHolding = false
        typing = false
        Haptics.soft()
        dictation.stop()
        // A hold that never reached the microphone ends here; otherwise the state change finishes it.
        if dictation.state == .idle { finishCapture() }
    }

    private func finishCapture() {
        guard let since = heldSince else { return }
        heldSince = nil
        let seconds = max(1, Int(Date.now.timeIntervalSince(since).rounded()))
        let caught = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        heard = ""
        // Nothing heard: whatever was typed stays in the field, untouched, and the line says why (felt too).
        guard !caught.isEmpty else {
            if dictation.notice != nil { Haptics.warning() }
            return
        }
        let words = Self.joined(typedBeforeHold, caught)
        typed = ""
        typedBeforeHold = ""
        // Said into an idea being corrected: the words are its new ones.
        if let editing { return commitEdit(editing, words: words) }
        guard let entry = withAnimation(reduceMotion ? nil : .smooth(duration: 0.4), { logbook.add(words, spokenSeconds: seconds) }) else { return }
        // It lands, then opens whole: what was heard is read on its card, never in the field. Opened in the same moment it is added,
        // the list kept the row's folded height.
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 50 : 420))
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { _ = expanded.insert(entry.id) }
        }
        logbook.keepDraft("")
        Haptics.success()
        justSaved = entry.id
        land(entry)
        tag(entry)
    }

    private func addTyped() {
        let words = typed
        if let editing { return commitEdit(editing, words: words) }
        guard let entry = withAnimation(reduceMotion ? nil : .smooth(duration: 0.4), { logbook.add(words) }) else { return }
        typed = ""
        logbook.keepDraft("")
        Haptics.apply()
        justSaved = entry.id
        land(entry)
        tag(entry)
    }

    /// Edit, on holding a card: its words go into the field to be corrected, the keyboard comes up and the card is outlined while it waits.
    /// Return or the arrow saves them in place (its day and how it came in stay); Cancel leaves it as it was.
    private func startEdit(_ entry: LogbookEntry) {
        guard !isSelecting, !isHolding else { return }
        if editing == nil { draftBeforeEdit = typed }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { editing = entry.id }
        typed = entry.text
        typing = true
        justSaved = entry.id
    }

    private func cancelEdit() {
        guard editing != nil else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { editing = nil }
        typed = draftBeforeEdit
        draftBeforeEdit = ""
    }

    private func commitEdit(_ id: UUID, words: String) {
        // Emptied: nothing to change (Delete is how an idea goes).
        guard let entry = withAnimation(reduceMotion ? nil : .smooth(duration: 0.35), { logbook.edit(id, text: words) }) else { return cancelEdit() }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { editing = nil }
        typed = draftBeforeEdit
        draftBeforeEdit = ""
        typing = false
        Haptics.apply()
        justSaved = id
        land(entry)
        tag(entry)
    }

    /// Swiped or held away: the card shrinks out and the list closes over it, with Undo for 4 s.
    private func delete(_ entry: LogbookEntry) {
        remove([entry.id], message: String(localized: "Idea deleted"))
    }

    /// Select all beside the trash: picks every idea, or lets them all go once they are.
    private func toggleSelectAll() {
        let all = logbook.waiting.map(\.id)
        if !all.isEmpty, all.allSatisfy(selection.contains) { selection.removeAll() } else { selection.formUnion(all) }
    }

    /// The bar's trash: what is picked goes together, with one Undo.
    private func deleteSelection() {
        guard !selection.isEmpty else { return }
        let picked = selection
        isSelecting = false
        remove(picked, message: String(localized: "\(picked.count) deleted"))
    }

    private func remove(_ ids: Set<UUID>, message: String) {
        if let editing, ids.contains(editing) { cancelEdit() }
        Haptics.delete()
        let removed = withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { logbook.delete(ids) }
        guard !removed.isEmpty else { return }
        toast.show(message, action: ToastAction(title: String(localized: "Undo")) { [logbook, reduceMotion] in
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { logbook.restore(removed) }
        })
    }

    /// The idea just saved slides in at the top of the list and is outlined for a moment, so the eye follows it there.
    private func land(_ entry: LogbookEntry) {
        highlighted = entry.id
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            if highlighted == entry.id { highlighted = nil }
        }
    }

    /// The topic, picked on this iPhone.
    private func tag(_ entry: LogbookEntry) {
        Task {
            if let topic = await tagging.topic(forText: entry.text) { logbook.setTopic(topic.id, of: entry.id) }
        }
    }

    private func writeIdea(_ entry: LogbookEntry) {
        // One star at a time: a second tap while the first card lights would start a second script.
        guard writingID == nil else { return }
        guard aiStatus.isAvailable else {
            logbook.markShaped(entry.id, as: starter.writeByHand(idea: entry.text))
            dismiss()
            return
        }
        // An idea in a language Apple Intelligence can't draft in doesn't light up: the toast says why (with "Write it"), the idea waits.
        guard starter.drafting(before: entry.text).isAvailable else {
            starter.write(idea: entry.text) { [logbook] scriptID in logbook.markShaped(entry.id, as: scriptID) }
            dismiss()
            return
        }
        // The card lights in violet, then the star leaves from its Write button.
        writingID = entry.id
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 280))
            // The idea stops waiting only once the star has made it a script: Cancel leaves it in the Logbook.
            starter.write(idea: entry.text, from: writeCenters[entry.id]) { [logbook] scriptID in logbook.markShaped(entry.id, as: scriptID) }
            dismiss()
        }
    }
}
