//
//  MyCueVoicePage.swift
//  Cue Studio
//

import SwiftUI

/// 9.3 · My Cue Voice, the full page: the meter, the next question, and the three layers — Essentials (kind of creator, topics,
/// audience, tone), Personality (style, formats, openings, endings, phrases, what to avoid, reach) and Proof (examples) — each row
/// opening the question sheet on its field, then "What Cue sends": the brief as the model reads it. Without Apple Intelligence the data stays saved and
/// editable, and the page says the voice needs it.
struct MyCueVoicePage: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(VoiceQuestionScheduler.self) private var scheduler
    @Environment(AIStatus.self) private var aiStatus

    @State private var setup: ProfileVoiceSetup?
    @State private var editing: VoiceField?
    @State private var confirmsReset = false
    @Environment(ToastService.self) private var toast

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !aiStatus.isAvailable { needsAI }
                if aiStatus.isAvailable, let next = scheduler.remaining.first {
                    nextQuestion(next)
                }
                ForEach(VoiceLayer.allCases, id: \.self) { layerView($0) }
                NavigationLink { VoiceFineTunePage() } label: {
                    HStack {
                        Text("Fine-tune how you sound").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink3)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: Metrics.hitTarget + 6)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("voicePage.fineTune")
                whatCueSends
                resetQuestions
            }
            .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
        }
        .skyBackground()
        .navigationTitle("My Cue Voice")
        .toolbarTitleDisplayMode(.inline)
        .sheet(item: $setup) { setup in
            VoiceSetupSheet(mode: setup.mode, profile: profile.profile, startAt: setup.startAt)
        }
        .sheet(item: $editing) { field in
            if field == .examples {
                VoiceExamplesSheet()
            } else {
                VoiceQuestionSheet(model: VoiceQuestionSheetModel(
                    question: field.questions[0], mode: .edit, fieldQuestions: field.questions,
                    profile: profile, scheduler: scheduler, toast: toast
                ))
            }
        }
        .accessibilityIdentifier("voicePage")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VoiceMeter(strength: current.voiceStrength, level: current.voiceLevel)
            Text(current.voiceSentence.isEmpty ? String(localized: "Answer a few questions and Cue starts sounding like you.") : current.voiceSentence)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("voicePage.sentence")
            Toggle("Use my voice in AI scripts", isOn: profile.writesInMyVoiceBinding { setup = ProfileVoiceSetup(mode: .missing) })
                .font(.subheadline)
                .tint(Palette.successText)
                .accessibilityIdentifier("voicePage.toggle")
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
    }

    private var needsAI: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("My Cue Voice needs Apple Intelligence")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text("Your answers stay saved and you can still edit them.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
        } icon: {
            Image(systemName: "sparkles").foregroundStyle(Palette.aiText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("voicePage.needsAI")
    }

    // MARK: - Layers

    private func layerView(_ layer: VoiceLayer) -> some View {
        let fields = VoiceField.fields(of: layer)
        let points = fields.reduce(0) { $0 + current.points(for: $1) }
        let total = fields.reduce(0) { $0 + $1.weight }
        return self.layer(title: layerTitle(layer), points: points, of: total) {
            ForEach(Array(fields.enumerated()), id: \.element) { index, field in
                row(
                    title: field.title, value: current.value(for: field), isFilled: current.isFilled(field), isFirst: index == 0,
                    identifier: "voicePage.row.\(field.rawValue)"
                ) { editing = field }
            }
        }
    }

    private func layerTitle(_ layer: VoiceLayer) -> String {
        switch layer {
        case .essentials: String(localized: "Essentials")
        case .personality: String(localized: "Personality")
        case .proof: String(localized: "Proof")
        }
    }

    private func layer<Content: View>(title: String, points: Int, of total: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(CueStudioFont.hud)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Palette.ink2)
                Spacer()
                Text("\(points) / \(total)")
                    .font(CueStudioFont.hud)
                    .tracking(1)
                    .foregroundStyle(points == total ? Palette.successText : Palette.inkHint)
            }
            .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        }
    }

    /// The next question in the queue, answered right here.
    private func nextQuestion(_ question: VoiceQuestion) -> some View {
        Button { editing = question.field } label: {
            HStack(spacing: 10) {
                Text(verbatim: "✦").foregroundStyle(Palette.aiText)
                Text(question.title)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Answer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accText)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: Metrics.hitTarget + 6)
            .background(Palette.aiFill, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).strokeBorder(Palette.aiBorder, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("voicePage.next")
    }

    private func row(title: String, value: String, isFilled: Bool, isFirst: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isFilled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isFilled ? Palette.successText : Palette.ink3)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 104, alignment: .leading)
                Text(value.isEmpty ? String(localized: "Not set") : value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(value.isEmpty ? Palette.inkHint : Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: Metrics.hitTarget + 6)
            .overlay(alignment: .top) { if !isFirst { Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 14) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Reset

    /// "Reset My Cue Voice" (08 §4): the history of the tips starts over — what was snoozed, paused or skipped. The answers stay.
    private var resetQuestions: some View {
        Button { confirmsReset = true } label: {
            Text("Reset My Cue Voice")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("voicePage.reset")
        .confirmationDialog("Reset My Cue Voice?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Ask me everything again") {
                scheduler.reset()
                toast.show(String(localized: "Questions reset"))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Skipped and snoozed questions come back. Your answers stay.")
        }
    }

    // MARK: - What Cue sends

    private var whatCueSends: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("What Cue sends", systemImage: "sparkles")
                .font(CueStudioFont.hud)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Palette.aiText)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text("What Cue tells Apple Intelligence · on device")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                let brief = ScriptPromptBuilder.voiceBrief(current)
                Text(brief.isEmpty ? String(localized: "Nothing yet. Set up the first questions and it shows here.") : brief)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(brief.isEmpty ? Palette.inkHint : Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("voicePage.brief")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { MyCueVoicePage() }
}
#endif
