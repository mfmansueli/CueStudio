//
//  VoiceSetupSheet.swift
//  Cue Studio
//

import SwiftUI

/// The short setup behind "Write in my voice": what you create, who you talk to and how you talk.
/// It asks only what the profile still lacks (or all three, to edit), writes the answers into the
/// same Profile fields the Creator Voice section edits, and turns the voice on. Closing it without
/// saving changes nothing.
struct VoiceSetupSheet: View {
    /// Which questions the sheet opens with: what is missing, or all of them to edit what was answered.
    enum Mode: String, Identifiable {
        case missing, edit

        var id: String { rawValue }
    }

    let mode: Mode
    var onSaved: () -> Void = {}

    @Environment(CreatorProfileService.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @State private var draft: VoiceSetupDraft

    init(mode: Mode, profile: CreatorProfile, onSaved: @escaping () -> Void = {}) {
        self.mode = mode
        self.onSaved = onSaved
        _draft = State(initialValue: VoiceSetupDraft(profile: profile, steps: mode == .edit ? VoiceSetupStep.allCases : nil))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SheetHeader(
                        title: mode == .edit ? String(localized: "Edit your style") : String(localized: "Set up your style"),
                        subtitle: String(localized: "Saved to your Profile."),
                        onClose: { dismiss() }
                    )
                    ForEach(draft.steps) { step in
                        section(for: step)
                    }
                }
                .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
            }
            .scrollBounceBehavior(.basedOnSize)
            Button(action: save) {
                Text("Save and use my style")
            }
            .buttonStyle(.cuePrimary(.large))
            .disabled(!draft.canSave)
            .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
            .accessibilityIdentifier("voiceSetup.saveButton")
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("voiceSetup.sheet")
    }

    // MARK: - Pieces

    @ViewBuilder
    private func section(for step: VoiceSetupStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.question)
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            switch step {
            case .niche:
                chips(Niche.allCases, label: \.label, isPicked: { draft.isPicked($0) }, isOn: draft.canAddNiche, key: "niche") { draft.toggle($0) }
                limitNote(draft.nicheCap)
            case .audience:
                chips(Vocabulary.allCases, label: \.audienceLabel, isPicked: { draft.isPicked($0) }, isOn: true, key: "audience") { draft.choose($0) }
            case .tone:
                chips(VoiceSound.allCases, label: \.label, isPicked: { draft.isPicked($0) }, isOn: draft.canAddSound, key: "tone") { draft.toggle($0) }
                limitNote(draft.soundCap)
            }
        }
    }

    /// Choices that wrap, one tap each. Past the limit the unpicked ones dim: they can't be added.
    private func chips<Option: Identifiable & Hashable>(
        _ options: [Option], label: @escaping (Option) -> String, isPicked: @escaping (Option) -> Bool,
        isOn canAdd: Bool, key: String, pick: @escaping (Option) -> Void
    ) -> some View where Option.ID == String {
        FlowLayout(spacing: 8, lineSpacing: 0) {
            ForEach(options) { option in
                let picked = isPicked(option)
                Button {
                    Haptics.selection()
                    pick(option)
                } label: {
                    FilterChip(label: label(option), isSelected: picked)
                        .fixedSize()
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                        .opacity(picked || canAdd ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("voiceSetup.\(key).\(option.id)")
            }
        }
    }

    private func limitNote(_ limit: Int) -> some View {
        Text("Pick up to \(limit)")
            .font(.footnote)
            .foregroundStyle(Palette.ink2)
    }

    // MARK: - Actions

    private func save() {
        guard draft.canSave else { return }
        draft.save(to: profile)
        Haptics.apply()
        onSaved()
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
