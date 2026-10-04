//
//  LogbookView.swift
//  Cue Studio
//

import SwiftUI

/// The Logbook: "Catch it now. Write it later." Hold the button and say an idea, or type it; each waits as a card with
/// "✦ Write", which turns it into a script on the script page (Shape is only for adding cues). Without Apple Intelligence
/// the card says "Write it" and opens a blank draft titled with the idea. Speaking is on-device recognition: only the words are
/// kept, never the sound.
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
    @State private var heard = ""
    @State private var isHolding = false
    @State private var heldSince: Date?
    @FocusState private var typing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                captureButton.padding(.top, 28)
                Text(isHolding ? (heard.isEmpty ? String(localized: "Listening…") : heard) : String(localized: "Hold to capture an idea"))
                    .font(.system(size: 17))
                    .foregroundStyle(isHolding ? Palette.ink : Palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .accessibilityIdentifier("logbook.status")
                if let notice = dictation.notice, !isHolding {
                    Text(notice.message)
                        .font(.footnote).foregroundStyle(Palette.warnText).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.horizontal, 20)
                }
                typeField.padding(.top, 24)
                list.padding(.top, 28)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.bg)
        .onChange(of: dictation.state) { _, state in
            if state == .idle, heldSince != nil { finishCapture() }
        }
        .onDisappear { dictation.cancel() }
        .accessibilityIdentifier("logbook.sheet")
    }

    // MARK: - Parts

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Logbook").font(.system(size: 34, weight: .bold)).foregroundStyle(Palette.ink)
                Text("Catch it now. Write it later.").font(.system(size: 18)).foregroundStyle(Palette.ink2)
            }
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("logbook.doneButton")
        }
        .padding(.top, 24)
    }

    /// Hold to talk: the circle grows and its rings follow the voice while the finger stays.
    private var captureButton: some View {
        ZStack {
            if isHolding {
                Circle().stroke(Palette.acc.opacity(0.35), lineWidth: 2)
                    .frame(width: 150 + dictation.level * 60, height: 150 + dictation.level * 60)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: dictation.level)
            }
            Circle()
                .fill(Palette.acc)
                .frame(width: isHolding ? 130 : 112, height: isHolding ? 130 : 112)
                .shadow(color: Palette.acc.opacity(isHolding ? 0.6 : 0.3), radius: isHolding ? 28 : 18)
            CueIconView(.dictate, size: 40).foregroundStyle(Palette.accInk)
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .contentShape(Circle())
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isHolding)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 80, pressing: { pressing in
            pressing ? beginCapture() : endCapture()
        }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Capture an idea by voice"))
        .accessibilityHint(Text("Double tap and hold, then speak"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Start or stop")) { isHolding ? endCapture() : beginCapture() }
        .accessibilityIdentifier("logbook.captureButton")
    }

    private var typeField: some View {
        let shape = Capsule()
        return HStack(spacing: 12) {
            Image(systemName: "pencil").foregroundStyle(Palette.ink2)
            TextField("Or type an idea…", text: $typed)
                .focused($typing)
                .submitLabel(.done)
                .onSubmit(addTyped)
                .accessibilityIdentifier("logbook.field")
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Palette.surface2, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
    }

    @ViewBuilder
    private var list: some View {
        let waiting = logbook.waiting
        HStack {
            Text("WAITING · \(waiting.count)")
            Spacer()
            Text("NEWEST FIRST")
        }
        .font(CueStudioFont.hud)
        .tracking(1.2)
        .foregroundStyle(Palette.ink2)
        if waiting.isEmpty {
            // The empty state (E): the mark, what this is for and how to start; the capture button above is its action.
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
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("logbook.empty")
        }
        VStack(spacing: 10) {
            ForEach(waiting) { entry in card(entry) }
        }
        .padding(.top, 12)
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

    private func beginCapture() {
        guard !isHolding, dictation.state == .idle else { return }
        isHolding = true
        heard = ""
        heldSince = .now
        Haptics.selection()
        let request = languages.dictationRequest(existingText: "")
        Task { await dictation.start(language: request) { heard = $0 } }
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
        let words = heard
        heard = ""
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
        let scriptID = aiStatus.isAvailable ? starter.write(idea: entry.text) : starter.writeByHand(idea: entry.text)
        logbook.markShaped(entry.id, as: scriptID)
        dismiss()
    }
}
