//
//  VoiceSetupSheet.swift
//  Cue Studio
//

import SwiftUI

/// My Cue Voice (V1): four questions, one at a time, with a progress bar ("01 / 04"): what kind of
/// creator, what you talk about, who you talk to, how you sound. Answers go to the same profile
/// fields Profile edits. A creator with an idea waiting on the card finishes with "Write my script",
/// and the script that comes is the preview of the voice (see `VoicePreviewStrip`).
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
    @Environment(ToastService.self) private var toast
    @State private var draft: VoiceSetupDraft
    @State private var index = 0
    @State private var showsExample = false
    private let confirmsExistingValues: Bool

    init(
        mode: Mode, profile: CreatorProfile, ideaText: String? = nil, startAt: VoiceSetupStep? = nil,
        onSaved: @escaping (Bool) -> Void = { _ in }
    ) {
        self.mode = mode
        self.ideaText = ideaText
        self.startAt = startAt
        self.onSaved = onSaved
        let draft = VoiceSetupDraft(profile: profile, steps: mode == .edit ? VoiceSetupStep.allCases : nil)
        confirmsExistingValues = draft.confirmsExistingValues
        _index = State(initialValue: startAt.flatMap { draft.steps.firstIndex(of: $0) } ?? 0)
        _draft = State(initialValue: draft)
    }

    private var step: VoiceSetupStep { draft.steps[min(index, draft.steps.count - 1)] }
    private var isLast: Bool { index >= draft.steps.count - 1 }
    private var hasIdea: Bool { !(ideaText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }

    /// Whether the answer for the question showing allows going on.
    private var canContinue: Bool {
        switch step {
        case .role: draft.role != nil
        case .niche: !draft.niches.isEmpty
        case .audience: draft.vocabulary != nil
        case .tone: !draft.sounds.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.question)
                            .font(.system(size: 30, weight: .bold))
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
        // A container of its own: the sheet's identifier would otherwise replace its controls' (Continue's).
        .sheet(isPresented: $showsExample) { VoiceExamplesSheet() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voiceSetup.sheet")
    }

    // MARK: - Pieces

    private var subtitle: LocalizedStringKey {
        switch step {
        case .role: "Pick the closest. Change it anytime."
        case .niche: "Cue writes ideas and scripts about them."
        case .audience: confirmsExistingValues ? "Confirm what’s here, or change it." : "They decide the words Cue uses."
        case .tone: confirmsExistingValues ? "Confirm what’s here, or change it." : "Pick the closest. Change it anytime."
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .role:
            VoiceRoleStep(draft: draft) { role in
                Haptics.selection()
                draft.choose(role)
            }
        case .niche:
            VoiceNicheStep(draft: draft) { niche in
                Haptics.selection()
                if !draft.toggle(niche) { toast.show(VoiceLimits.message(max: draft.nicheCap, noun: String(localized: "topics"))) }
            }
        case .audience:
            VoiceAudienceStep(draft: draft) { vocabulary in
                Haptics.selection()
                draft.choose(vocabulary)
            } onLevel: { level in
                Haptics.selection()
                draft.choose(level)
            }
        case .tone:
            VoiceToneStep(draft: draft) { sound in
                Haptics.selection()
                if !draft.toggle(sound) { toast.show(String(localized: "Max \(draft.soundCap) · tap to remove")) }
            }
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
            VoiceFlowProgress(step: index, count: draft.steps.count)
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Text(mode == .edit ? "Cancel" : "Not now")
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
                .disabled(!draft.canSave)
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
        if isLast {
            save(writesScript: hasIdea && mode != .edit)
        } else {
            advance()
        }
    }

    private func save(writesScript: Bool) {
        guard draft.canSave else { return }
        draft.save(to: profile)
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
