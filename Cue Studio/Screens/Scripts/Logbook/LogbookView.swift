//
//  LogbookView.swift
//  Cue Studio
//

import SwiftUI

/// The Logbook: "Catch it now. Write it later." Hold the button and say an idea (its words arrive in the field, after anything typed
/// there, and letting go saves them; or tap it once to start and again to finish), or type it; each waits as a card with
/// "✦ Write", which turns it into a script on the script page (Shape is only for adding cues). Without Apple Intelligence
/// the card says "Write it" and opens a blank draft titled with the idea. Speaking is on-device recognition: only the words are
/// kept, never the sound. Swipe an idea to delete it (or hold it).
struct LogbookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LogbookService.self) private var logbook
    @Environment(DictationService.self) private var dictation
    @Environment(LanguageService.self) private var languages
    @Environment(TopicTaggingService.self) private var tagging
    @Environment(ScriptStarter.self) private var starter
    @Environment(AIStatus.self) private var aiStatus
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
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            // One list for the whole page, so an idea can be swiped away the system's way.
            List {
                Group {
                    captureButton.padding(.top, 8)
                    // One line that never changes size: the words themselves go into the field below (they used to grow here and push
                    // the page down and up while the creator spoke).
                    Text(statusLine)
                        .font(.system(size: 17))
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
                    typeField.padding(.top, 16)
                    listHeader.padding(.top, 20)
                    if logbook.waiting.isEmpty { emptyState }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: Metrics.gutter, bottom: 0, trailing: Metrics.gutter))
                ForEach(logbook.waiting) { entry in
                    card(entry)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: Metrics.gutter, bottom: 8, trailing: Metrics.gutter))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { logbook.delete(entry.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            // The system's large title, with the line under it as its subtitle; both fold into the bar as the list scrolls.
            .navigationTitle("Logbook")
            .navigationSubtitle("Catch it now. Write it later.")
            .navigationBarTitleDisplayMode(.large)
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
        .accessibilityIdentifier("logbook.sheet")
    }

    // MARK: - Parts

    /// Hold to talk: the circle grows and its rings follow the voice while the finger stays. They grow by scale inside an area of a fixed
    /// height (the largest ring fits), so the animation never resizes anything around it (it used to push the field and the list).
    private var captureButton: some View {
        ZStack {
            if isHolding {
                Circle().stroke(Palette.acc.opacity(0.35), lineWidth: 2)
                    .frame(width: 150, height: 150)
                    .scaleEffect(1 + dictation.level * 0.4)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: dictation.level)
            }
            Circle()
                .fill(Palette.acc)
                .frame(width: 112, height: 112)
                .scaleEffect(isHolding ? 130.0 / 112.0 : 1)
                .shadow(color: Palette.acc.opacity(isHolding ? 0.6 : 0.3), radius: isHolding ? 28 : 18)
            CueIconView(.dictate, size: 40).foregroundStyle(Palette.accInk)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .contentShape(Circle())
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isHolding)
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

    /// Where an idea is typed, and where the words of a spoken one arrive while the button is held.
    private var typeField: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: isHolding ? "mic.fill" : "pencil")
                .foregroundStyle(isHolding ? Palette.accText : Palette.ink2)
                .accessibilityHidden(true)
            TextField("Or type an idea…", text: $typed, axis: .vertical)
                .lineLimit(1...4)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 17)
        .frame(minHeight: 56)
        .background(Palette.surface2, in: shape)
        .overlay(shape.strokeBorder(isHolding ? Palette.accLine : Palette.glassBorder, lineWidth: isHolding ? 1 : 0.5))
    }

    private var listHeader: some View {
        HStack {
            Text("WAITING · \(logbook.waiting.count)")
            Spacer()
            Text("NEWEST FIRST")
        }
        .font(CueStudioFont.hud)
        .tracking(1.2)
        .foregroundStyle(Palette.ink2)
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
                    Text(meta(entry)).font(CueStudioFont.hud).tracking(0.8).foregroundStyle(Palette.ink2)
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
            .accessibilityIdentifier("logbook.write")
        }
        .padding(14)
        .background(Palette.surface, in: shape)
        .cardDepth(shape)
        .contextMenu {
            Button(role: .destructive) { logbook.delete(entry.id) } label: { Label("Delete", systemImage: "trash") }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("logbook.entry")
    }

    private func meta(_ entry: LogbookEntry) -> String {
        let when = entry.createdAt.formatted(.relative(presentation: .named).locale(.interface)).uppercased()
        guard let seconds = entry.spokenSeconds else { return String(localized: "TEXT · \(when)") }
        return "\(DurationText.clock(Double(seconds))) · \(when)"
    }

    private func color(for entry: LogbookEntry) -> Color? {
        guard let id = entry.topic, let index = tagging.topics.firstIndex(where: { $0.id == id }) else { return nil }
        return OnboardingTopic.color(at: index)
    }

    // MARK: - Capturing

    /// The one line under the button, which never changes size: what it does, what it hears, or how to finish.
    private var statusLine: String {
        if isLocked { return String(localized: "Tap the button again to finish") }
        return isHolding ? String(localized: "Listening…") : String(localized: "Hold to capture an idea, or tap to start")
    }

    /// A finger down starts listening, unless a tap left it going: that finger is the one that ends it.
    private func press() {
        pressedAt = .now
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
        Haptics.selection()
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
        guard let entry = logbook.add(words, spokenSeconds: seconds) else { return }
        Haptics.success()
        tag(entry)
    }

    private func addTyped() {
        guard let entry = logbook.add(typed) else { return }
        typed = ""
        Haptics.apply()
        tag(entry)
    }

    /// The topic, picked on this iPhone.
    private func tag(_ entry: LogbookEntry) {
        Task {
            if let topic = await tagging.topic(forText: entry.text) { logbook.setTopic(topic.id, of: entry.id) }
        }
    }

    private func writeIdea(_ entry: LogbookEntry) {
        if aiStatus.isAvailable {
            // The idea stops waiting only once the star has made it a script: Cancel leaves it in the Logbook.
            starter.write(idea: entry.text) { [logbook] scriptID in logbook.markShaped(entry.id, as: scriptID) }
        } else {
            logbook.markShaped(entry.id, as: starter.writeByHand(idea: entry.text))
        }
        dismiss()
    }
}
