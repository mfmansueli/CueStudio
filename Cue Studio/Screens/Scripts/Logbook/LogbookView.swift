//
//  LogbookView.swift
//  Cue Studio
//

import SwiftUI

/// The Logbook: "Catch it now. Write it later." Hold the button and say an idea (its words arrive in the field, after anything typed
/// there, and letting go saves them; or tap it once to start and again to finish), or type it; each waits as a card with
/// "✦ Write", which turns it into a script on the script page (Shape is only for adding cues). Without Apple Intelligence
/// the card says "Write it" and opens a blank draft titled with the idea. Speaking is on-device recognition: only the words are
/// kept, never the sound. Swipe an idea to delete it (or hold it). The ideas are grouped by day (`LogbookDays`). While the field has the
/// keyboard, the big microphone steps aside into a small one beside it, so the ideas stay in sight above the keyboard.
struct LogbookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LogbookService.self) private var logbook
    @Environment(DictationService.self) private var dictation
    @Environment(LanguageService.self) private var languages
    @Environment(TopicTaggingService.self) private var tagging
    @Environment(ScriptStarter.self) private var starter
    @Environment(AIStatus.self) private var aiStatus
    @Environment(PresentationService.self) private var presentation
    /// The note a notification was about: brought into view and outlined in yellow.
    @State private var focused: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var typed = ""
    /// What was in the field when the hold began: the heard words go after it.
    @State private var typedBeforeHold = ""
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
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            // One list for the whole page, so an idea can be swiped away the system's way.
            List {
                Group {
                    if !isCompact {
                        // Typing, it shrinks away toward the small one beside the field (and grows back from there).
                        captureButton.padding(.top, 8)
                            .transition(.scale(scale: 0.25, anchor: .bottomTrailing).combined(with: .opacity))
                        // One line that never changes size: the words themselves go into the field below (they used to grow here and
                        // push the page down and up while the creator spoke).
                        Text(statusLine)
                            .font(.system(size: 16))
                            .foregroundStyle(isHolding ? Palette.ink : Palette.ink2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityIdentifier(isLocked ? "logbook.tapToFinish" : "logbook.status")
                        if let notice = dictation.notice, !isHolding {
                            Text(notice.message)
                                .font(.footnote).foregroundStyle(Palette.warnText).multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    HStack(spacing: 10) {
                        typeField
                        if isCompact { compactMic.transition(.scale(scale: 2.2, anchor: .topLeading).combined(with: .opacity)) }
                    }
                    .padding(.top, isCompact ? 8 : 12)
                    if logbook.waiting.isEmpty { emptyState }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: Metrics.gutter, bottom: 0, trailing: Metrics.gutter))
                ForEach(LogbookDays.days(of: logbook.waiting)) { day in
                    dayHeader(day.title)
                    ForEach(day.entries) { entry in
                        card(entry)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 6, trailing: Metrics.gutter))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { delete(entry) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: isCompact)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .task {
                guard let id = presentation.logbookFocus else { return }
                presentation.logbookFocus = nil
                focused = id
                proxy.scrollTo(id, anchor: .center)
            }
            .onChange(of: justSaved) { _, id in
                guard let id else { return }
                justSaved = nil
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { proxy.scrollTo(id, anchor: .bottom) }
            }
            }
            // The system's large title, with the line under it as its subtitle; both fold into the bar as the list scrolls.
            .navigationTitle("Logbook")
            .navigationSubtitle("Catch it now. Write it later.")
            // Typing, the title folds into the bar so the ideas have the room above the keyboard.
            .navigationBarTitleDisplayMode(isCompact ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("logbook.doneButton")
                }
            }
        }
        .onChange(of: dictation.state) { _, state in
            if state == .idle, heldSince != nil {
                isLocked = false
                finishCapture()
            }
        }
        .onDisappear {
            isLocked = false
            dictation.cancel()
        }
        .task {
            // Once, as it opens: the microphone breathes, to say where to tap.
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .milliseconds(350))
            inviteTurn += 1
        }
        .onChange(of: hasWords) { _, now in
            // The button beside the field turns into the arrow that saves: felt as well as seen.
            if now, isCompact { Haptics.selection() }
        }
        .accessibilityIdentifier("logbook.sheet")
    }

    // MARK: - Parts

    /// Hold to talk: the circle grows and its rings follow the voice while the finger stays. They grow by scale inside an area of a fixed
    /// height (the largest ring fits), so the animation never resizes anything around it (it used to push the field and the list).
    private var captureButton: some View {
        ZStack {
            if isHolding {
                // Ripples leave the circle while it listens, further with a louder voice.
                LogbookRipples(level: dictation.level).transition(.opacity)
            }
            Circle()
                .fill(Palette.acc)
                .frame(width: 112, height: 112)
                .scaleEffect((isHolding ? 130.0 / 112.0 : 1) * (isPressed ? 0.92 : 1))
                .shadow(color: Palette.acc.opacity(isHolding ? 0.6 : 0.3), radius: isHolding ? 28 : 18)
                .keyframeAnimator(initialValue: 1.0, trigger: inviteTurn) { circle, scale in
                    circle.scaleEffect(scale)
                } keyframes: { _ in
                    CubicKeyframe(1.08, duration: 0.35)
                    SpringKeyframe(1.0, duration: 0.6, spring: .bouncy)
                }
            CueIconView(.dictate, size: 40)
                .foregroundStyle(Palette.accInk)
                .keyframeAnimator(initialValue: 1.0, trigger: listenTurn) { icon, scale in
                    icon.scaleEffect(scale)
                } keyframes: { _ in
                    CubicKeyframe(1.25, duration: 0.12)
                    SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .contentShape(Circle())
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isHolding)
        .animation(isPressed ? CueMotion.pressIn : CueMotion.pressRelease, value: isPressed)
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

    /// Where an idea is typed, and where the words of a spoken one arrive while the button is held. It is one line high whether empty or
    /// not (the icon centred on it; it used to sit taller while empty and jump as typing began) and grows only for a longer idea.
    private var typeField: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: isHolding ? "mic.fill" : "pencil")
                .symbolSwap(value: isHolding)
                .foregroundStyle(isHolding ? Palette.accText : Palette.ink2)
                .frame(width: 18)
                .accessibilityHidden(true)
            TextField("Or type an idea…", text: $typed, axis: .vertical)
                .lineLimit(1...4)
                .tint(Palette.accText)
                .focused($typing)
                .submitLabel(.done)
                .onSubmit(addTyped)
                // The field grows to show a long idea, and Return still saves it (in a field that grows it would start a new line).
                .onChange(of: typed) { _, text in
                    guard text.contains("\n"), !isHolding else { return }
                    typed = text.replacingOccurrences(of: "\n", with: "")
                    addTyped()
                }
                .accessibilityIdentifier("logbook.field")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 56)
        .background(Palette.surface2, in: shape)
        .overlay(shape.strokeBorder(isHolding || typing ? Palette.accLine : Palette.glassBorder, lineWidth: isHolding ? 1 : 0.5))
    }

    /// The keyboard is the field's: the big microphone steps aside into `compactMic`.
    private var isCompact: Bool { typing && !isHolding }

    /// There are words in the field to save.
    private var hasWords: Bool { !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The button beside the field while typing, as in Messages: with words in the field it is the arrow that saves them to the Logbook
    /// (so where to confirm is never in doubt; a microphone there read as the confirm button); with the field empty it is the microphone,
    /// and a tap starts listening (the keyboard goes and the big one comes back, listening, with "Tap the button again to finish").
    private var compactMic: some View {
        Button {
            if hasWords {
                addTyped()
            } else {
                beginCapture()
                isLocked = true
            }
        } label: {
            Group {
                if hasWords {
                    Image(systemName: "arrow.up").font(.system(size: 22, weight: .bold))
                } else {
                    CueIconView(.dictate, size: 22)
                }
            }
            .foregroundStyle(Palette.accInk)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 56, height: 56)
            .background(Palette.acc, in: Circle())
            .shadow(color: Palette.acc.opacity(0.3), radius: 12)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyframeAnimator(initialValue: 1.0, trigger: hasWords) { button, scale in
            button.scaleEffect(scale)
        } keyframes: { _ in
            CubicKeyframe(1.14, duration: 0.1)
            SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
        }
        .animation(.snappy(duration: 0.2), value: hasWords)
        .accessibilityLabel(hasWords ? Text("Save to Logbook") : Text("Capture an idea by voice"))
        .accessibilityIdentifier(hasWords ? "logbook.save" : "logbook.compactMic")
    }

    /// "TODAY", "YESTERDAY", "MONDAY"…: a day's ideas start under it.
    private func dayHeader(_ title: String) -> some View {
        Text(verbatim: title)
            .hudFont()
            .interfaceTracking(1.2)
            .foregroundStyle(Palette.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: Metrics.gutter, bottom: 2, trailing: Metrics.gutter))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("logbook.day")
    }

    /// The empty state (E): the mark, what this is for and how to start; the capture button above is its action.
    private var emptyState: some View {
        VStack(spacing: 14) {
            EmptyStateMark(icon: .book)
            Text("Your Logbook is empty")
                .font(.system(size: 22, weight: .bold)).tracking(-0.44).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Hold the mic to catch an idea. Write it later.")
                .font(.system(size: 15)).foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 40)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("logbook.empty")
    }

    private func card(_ entry: LogbookEntry) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return HStack(spacing: 14) {
            Image(systemName: entry.isSpoken ? "mic.fill" : "pencil")
                .font(.system(size: 16))
                .foregroundStyle(entry.isSpoken ? Palette.accText : Palette.ink2)
                .frame(width: 44, height: 44)
                .background(entry.isSpoken ? Palette.accSoft : Palette.overlayFill, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text).font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(3)
                HStack(spacing: 6) {
                    Text(verbatim: LogbookDays.meta(for: entry)).hudFont().interfaceTracking(0.8).foregroundStyle(Palette.ink2)
                    if let color = color(for: entry) { Circle().fill(color).frame(width: 9, height: 9) }
                }
            }
            Spacer(minLength: 6)
            Button { writeIdea(entry) } label: {
                HStack(spacing: 4) {
                    if aiStatus.isAvailable { Text(verbatim: "✦") }
                    Text(aiStatus.isAvailable ? "Write" : "Write it")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(aiStatus.isAvailable ? Palette.aiTextStrong : Palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(aiStatus.isAvailable ? Palette.aiFill : Palette.fill, in: Capsule())
                .overlay { if aiStatus.isAvailable { Capsule().strokeBorder(Palette.aiBorder, lineWidth: 0.5) } }
            }
            .buttonStyle(.plain)
            .onGeometryChange(for: CGPoint.self) { proxy in
                let frame = proxy.frame(in: .global)
                return CGPoint(x: frame.midX, y: frame.midY)
            } action: { writeCenters[entry.id] = $0 }
            .accessibilityIdentifier("logbook.write")
        }
        .padding(14)
        .background(Palette.surface, in: shape)
        .overlay {
            if focused == entry.id || highlighted == entry.id {
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
        .contextMenu {
            Button(role: .destructive) { delete(entry) } label: { Label("Delete", systemImage: "trash") }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("logbook.entry")
    }

    private func color(for entry: LogbookEntry) -> Color? {
        guard let id = entry.topic, let index = tagging.topics.firstIndex(where: { $0.id == id }) else { return nil }
        return OnboardingTopic.color(at: index)
    }

    // MARK: - Capturing

    /// The one line under the button, which never changes size: what it does, what it hears, or how to finish.
    private var statusLine: String {
        if isLocked { return String(localized: "Tap the button again to finish") }
        return isHolding ? String(localized: "Listening…") : String(localized: "Hold to talk · tap to start")
    }

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

    /// Shorter than this, a touch is a tap.
    private static let tapLimit: TimeInterval = 0.35

    private func beginCapture() {
        guard !isHolding, dictation.state == .idle else { return }
        isHolding = true
        typing = false
        typedBeforeHold = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        heldSince = .now
        HapticPatterns.playListen()
        listenTurn += 1
        let request = languages.dictationRequest(existingText: typedBeforeHold)
        isStarting = true
        Task {
            await dictation.start(language: request) { heard in
                typed = typedBeforeHold.isEmpty ? heard : typedBeforeHold + " " + heard
            }
            isStarting = false
            // It never reached the microphone (no speech recognition here, no permission): there is nothing to keep listening for.
            if dictation.state == .idle, isLocked { stopCapture() }
        }
    }

    private func stopCapture() {
        isLocked = false
        endCapture()
    }

    private func endCapture() {
        guard isHolding else { return }
        isHolding = false
        Haptics.soft()
        dictation.stop()
        // A hold that never reached the microphone ends here; otherwise the state change finishes it.
        if dictation.state == .idle { finishCapture() }
    }

    private func finishCapture() {
        guard let since = heldSince else { return }
        heldSince = nil
        let seconds = max(1, Int(Date.now.timeIntervalSince(since).rounded()))
        // Nothing heard: whatever was typed stays in the field, untouched.
        guard typed.trimmingCharacters(in: .whitespacesAndNewlines) != typedBeforeHold else { return }
        let words = typed
        typed = ""
        typedBeforeHold = ""
        guard let entry = withAnimation(reduceMotion ? nil : .smooth(duration: 0.4), { logbook.add(words, spokenSeconds: seconds) }) else { return }
        Haptics.success()
        land(entry)
        tag(entry)
    }

    private func addTyped() {
        let words = typed
        guard let entry = withAnimation(reduceMotion ? nil : .smooth(duration: 0.4), { logbook.add(words) }) else { return }
        typed = ""
        Haptics.apply()
        justSaved = entry.id
        land(entry)
        tag(entry)
    }

    /// Swiped or held away: the card shrinks out and the list closes over it.
    private func delete(_ entry: LogbookEntry) {
        Haptics.delete()
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { logbook.delete(entry.id) }
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
