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
                if !aiStatus.isAvailable { needsAI }
                mainCard
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

    // MARK: - The card

    /// One material card, as in the Profile list (9.1): what Cue uses with its switch, the meter and the next question, then the layers as
    /// uppercase headers over rows of 52 pt or more.
    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
            ForEach(VoiceLayer.allCases, id: \.self) { layerView($0) }
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.profileBlockRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.profileBlockRadius, style: .continuous).strokeBorder(Palette.glassBorder.opacity(0.7), lineWidth: 0.5))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("✦ WHAT CUE USES")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(Palette.aiText)
                Spacer()
                Toggle("Use my voice in AI scripts", isOn: profile.writesInMyVoiceBinding { setup = ProfileVoiceSetup(mode: .missing) })
                    .labelsHidden()
                    .tint(Palette.successText)
                    .accessibilityLabel(Text("Use my voice in AI scripts"))
                    .accessibilityIdentifier("voicePage.toggle")
            }
            VoiceMeter(strength: current.voiceStrength, level: current.voiceLevel)
            if aiStatus.isAvailable, let next = scheduler.remaining.first { nextQuestion(next) }
        }
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
        VStack(alignment: .leading, spacing: 0) {
            Text(layerTitle(layer))
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Palette.ink2)
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 6, trailing: 16))
                .accessibilityAddTraits(.isHeader)
            ForEach(VoiceField.fields(of: layer), id: \.self) { field in
                row(
                    title: field.title, value: current.value(for: field),
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

    /// The next question in the queue, answered right here: "✦ Next: How do you usually end a video?  Answer".
    private func nextQuestion(_ question: VoiceQuestion) -> some View {
        Button { editing = question.field } label: {
            HStack(spacing: 10) {
                Text(verbatim: "✦").foregroundStyle(Palette.aiText)
                Text("Next: \(question.title)")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Answer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accText)
            }
            .contentShape(Rectangle())
            .frame(minHeight: Metrics.hitTarget)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("voicePage.next")
    }

    /// A row of the list: the field on the left in grey, what Cue knows on the right (or "+ Add · 1 tap" in yellow), a chevron, and a hairline above.
    private func row(title: String, value: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 96, alignment: .leading)
                Group {
                    if !value.isEmpty {
                        Text(value).font(.system(size: 16)).foregroundStyle(Palette.ink)
                    } else {
                        Text("+ Add · 1 tap").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.accText)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 16) }
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
