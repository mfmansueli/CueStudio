//
//  VoiceSetupSheet.swift
//  Cue Studio
//

import SwiftUI

/// My Cue Voice (V1): four questions, one at a time, with a progress bar ("01 / 04"): what kind of
/// creator, what you talk about, who is watching, how you sound. Each question is the field the editor
/// shows for the same answer (`VoiceEditorSheet`), and an answer is kept as it is given: only the shell
/// differs (Continue and "n of 4" here, Done there). A creator with an idea waiting on the card finishes
/// with "Write my script", and the script that comes is the preview of the voice (see `VoicePreviewStrip`).
struct VoiceSetupSheet: View {
    /// Which questions the sheet opens with: what is missing, or all of them to edit what was answered.
    enum Mode: String, Identifiable {
        case missing, edit

        var id: String { rawValue }
    }

    let mode: Mode
    /// The idea waiting on the card: the last question's button then writes it.
    var ideaText: String?
    /// The question to open on (an editable row of the profile); nil starts at the first.
    var startAt: VoiceSetupStep?
    /// Saved: `writesScript` is true when the creator asked for the idea to be written.
    var onSaved: (_ writesScript: Bool) -> Void = { _ in }

    @Environment(CreatorProfileService.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @State private var plan: VoiceSetupPlan
    @State private var index = 0
    @State private var showsExample = false

    init(
        mode: Mode, profile: CreatorProfile, ideaText: String? = nil, startAt: VoiceSetupStep? = nil,
        onSaved: @escaping (Bool) -> Void = { _ in }
    ) {
        self.mode = mode
        self.ideaText = ideaText
        self.startAt = startAt
        self.onSaved = onSaved
        let plan = VoiceSetupPlan(profile: profile, steps: mode == .edit ? VoiceSetupStep.allCases : nil)
        _index = State(initialValue: startAt.flatMap { plan.steps.firstIndex(of: $0) } ?? 0)
        _plan = State(initialValue: plan)
    }

    private var step: VoiceSetupStep { plan.steps[min(index, plan.steps.count - 1)] }
    private var isLast: Bool { index >= plan.steps.count - 1 }
    private var hasIdea: Bool { !(ideaText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }

    /// Whether the answer for the question showing allows going on.
    private var canContinue: Bool { VoiceSetupPlan.canContinue(step, in: profile.profile) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.question)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-0.56)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink2)
                    }
                    content
                    if step == .role {
                        Text("Doing more than one? Pick the one you film most.")
                            .font(.footnote)
                            .foregroundStyle(Palette.ink2)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(EdgeInsets(top: 16, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
            }
            .scrollBounceBehavior(.basedOnSize)
            bottomBar
        }
        .animation(.smooth(duration: 0.2), value: index)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .cueSheetSurface()
        // A container of its own: the sheet's identifier would otherwise replace its controls' (Continue's).
        .sheet(isPresented: $showsExample) { VoiceEditorSheet(field: .examples) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voiceSetup.sheet")
    }

    // MARK: - Pieces

    private var subtitle: LocalizedStringKey {
        switch step {
        case .role: "Pick the closest. Change it anytime."
        case .niche: "Cue writes ideas and scripts about them."
        case .audience: plan.confirmsExistingValues ? "Confirm what’s here, or change it." : "They decide the words Cue uses."
        case .tone: plan.confirmsExistingValues ? "Confirm what’s here, or change it." : "Pick the closest. Change it anytime."
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .role: VoiceRoleField()
        case .niche: VoiceTopicsField()
        case .audience: VoiceAudienceField()
        case .tone: VoiceToneField()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            if index > 0 {
                Button { index -= 1 } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("voiceSetup.back")
            }
            VoiceFlowProgress(step: index, count: plan.steps.count)
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Text(mode == .edit ? "Close" : "Not now")
                    .font(.body)
                    .foregroundStyle(Palette.ink2)
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("sheet.closeButton")
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 14)
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 4) {
            if step == .role {
                Button { advance() } label: {
                    Text("Skip this one")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("voiceSetup.skipRole")
            }
            Button(action: next) {
                Text(ctaLabel)
            }
            .buttonStyle(.cuePrimary(.large))
            .disabled(!canContinue)
            .accessibilityIdentifier("voiceSetup.saveButton")
            if isLast {
                Button { showsExample = true } label: {
                    Text("Add a voice example")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.aiText)
                        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("voiceSetup.addExample")
            }
            if isLast, hasIdea, mode != .edit {
                Button { save(writesScript: false) } label: {
                    Text("Just save my voice")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!plan.canFinish(in: profile.profile))
                .accessibilityIdentifier("voiceSetup.justSave")
            }
        }
        .padding(EdgeInsets(top: 6, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
    }

    private var ctaLabel: LocalizedStringKey {
        if !isLast { return "Continue" }
        if mode == .edit { return "Done" }
        return hasIdea ? "✦ Write my script" : "Done"
    }

    // MARK: - Actions

    private func advance() {
        guard !isLast else { return }
        index += 1
    }

    private func next() {
        guard canContinue else { return }
        // What an older build saved is kept as it is and counts as answered once the creator goes on with it.
        if !profile.profile.hasAnswered(step), profile.profile.isChosen(step) { profile.confirm(step) }
        if isLast {
            save(writesScript: hasIdea && mode != .edit)
        } else {
            advance()
        }
    }

    private func save(writesScript: Bool) {
        guard plan.canFinish(in: profile.profile) else { return }
        // Answered, the voice is on: this is what the creator set it up for.
        profile.setWritesInMyVoice(true)
        Haptics.apply()
        onSaved(writesScript)
        dismiss()
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        VoiceSetupSheet(mode: .missing, profile: CreatorProfile())
    }
    .previewEnvironment()
}
#endif
