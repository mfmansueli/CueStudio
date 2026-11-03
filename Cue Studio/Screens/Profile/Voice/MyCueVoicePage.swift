//
//  MyCueVoicePage.swift
//  Cue Studio
//

import SwiftUI

/// 9.3 · My Cue Voice, the full page: on top of the card, a section of its own with the voice's switch, the meter and the next question
/// (the owner, 03/11/2026), then the sections in the creator's order
/// (`VoicePageSection`, the owner's item 10) — each row opening the one editor on its field — and, under them,
/// **✦ Preview my voice** and **What Cue sends**. Without Apple
/// Intelligence the data stays saved and editable, and the page says the voice needs it. Where Ultra AI is offered and its invitation is due, a card
/// under the voice offers it for the next idea.
struct MyCueVoicePage: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(VoiceQuestionScheduler.self) private var scheduler
    @Environment(AIStatus.self) private var aiStatus
    @Environment(UltraScriptService.self) private var ultra
    @Environment(ScriptStarter.self) private var starter
    @Environment(ToastService.self) private var toast

    @State private var setup: ProfileVoiceSetup?
    @State private var editing: VoiceEditorField?
    @State private var showsPreview = false
    @State private var showsSends = false
    @State private var asksUltra = false
    @State private var confirmsClear = false

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !aiStatus.isAvailable { needsAI }
                mainCard
                if ultra.showsInvite {
                    UltraInviteCard(placement: .voice) { asksUltra = true } onClose: { ultra.invite?.close() }
                        .transition(.ultraFold)
                }
                Text("What Cue sends")
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 16)
                buttons
                clearButton
            }
            .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
        }
        .skyBackground()
        .navigationTitle("My Cue Voice")
        .toolbarTitleDisplayMode(.inline)
        .sheet(item: $setup) { setup in
            VoiceSetupSheet(mode: setup.mode, profile: profile.profile, startAt: setup.startAt)
        }
        .sheet(item: $editing) { VoiceEditorSheet(field: $0) }
        .sheet(isPresented: $showsPreview) { VoicePreviewSheet() }
        .sheet(isPresented: $asksUltra) {
            UltraConsentSheet {
                HapticPatterns.playUltraIgnite()
                withAnimation(UltraMotion.fold) {
                    ultra.consent.grant()
                    starter.choose(.ultra)
                }
                toast.show(String(localized: "Ultra AI writes your next idea"))
            }
        }
        .sheet(isPresented: $showsSends) {
            VoiceSendsSheet {
                // "Answer the 4 questions again": the sheet goes and the guided questions come.
                showsSends = false
                setup = ProfileVoiceSetup(mode: .edit)
            }
        }
        .accessibilityIdentifier("voicePage")
    }

    // MARK: - The card

    /// One material card, as in the Profile list (9.1): the voice at a glance in a section of its own, then the sections as uppercase
    /// headers over rows of 52 pt or more.
    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            status.padding(EdgeInsets(top: 8, leading: 8, bottom: 6, trailing: 8))
            VoiceNoticedCard { editing = $0 }
            ForEach(VoicePageSection.allCases) { sectionView($0) }
        }
        .profileBlock()
    }

    /// The voice at a glance, set apart inside the card on a raised panel (the owner, 03/11/2026): the switch named for what it does, how
    /// much Cue knows, and the next question with Answer.
    private var status: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("Use my voice in drafts")
                    .cueFont(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
                Toggle("Use my voice in drafts", isOn: profile.writesInMyVoiceBinding { setup = ProfileVoiceSetup(mode: .missing) })
                    .labelsHidden()
                    .tint(Palette.successText)
                    .accessibilityLabel(Text("Use my voice in drafts"))
                    .accessibilityIdentifier("voicePage.toggle")
            }
            VoiceMeter(strength: current.voiceStrength, level: current.voiceLevel)
            if aiStatus.isAvailable, let next = scheduler.remaining.first { nextQuestion(next) }
        }
        .padding(14)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.profileBlockRadius - 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voicePage.status")
    }

    private var needsAI: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("My Cue Voice needs Apple Intelligence")
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                Text("Your answers stay saved and you can still edit them.")
                    .cueFont(.footnote)
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

    // MARK: - Sections

    /// A section: its name as a title, white and bold over the grey names of its rows, with room above it so each area reads as its own
    /// (the owner, 03/11/2026: the uppercase grey names were lost among the rows').
    private func sectionView(_ section: VoicePageSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .cueFont(.headline, weight: .bold)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(EdgeInsets(top: 26, leading: 16, bottom: 10, trailing: 16))
                .accessibilityAddTraits(.isHeader)
            ForEach(section.rows) { row in
                VoicePageRowView(row: row, profile: current) { editing = VoiceEditorField(row) }
            }
            // Where the proof goes, said where it is given: both Apple Intelligence routes, never Ultra AI (the owner's D1; `AIDisclosure`).
            if section == .proof {
                Text(AIDisclosure.proof)
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                    .accessibilityIdentifier("voicePage.proofNote")
            }
        }
    }

    /// The next question in the queue, answered right here on a strip of its own: "✦ Next: How do you usually end a video?  Answer".
    private func nextQuestion(_ question: VoiceQuestion) -> some View {
        Button { editing = VoiceEditorField(question.field) } label: {
            HStack(spacing: 10) {
                Text(verbatim: "✦").foregroundStyle(Palette.aiText)
                Text("Next: \(question.title)")
                    .cueFont(.subheadline, weight: .medium)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Answer")
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.accText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: Metrics.hitTarget)
            .background(Palette.surface3, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("voicePage.next")
    }

    // MARK: - Clearing

    /// "Clear my answers" (the owner, 03/11/2026: to start the voice over and test it): after a question, every answer, example and what Cue
    /// learned goes, and the tips and the invitation start over; the themes stay.
    private var clearButton: some View {
        Button { confirmsClear = true } label: {
            Text("Clear my answers")
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.dangerText)
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("voicePage.clear")
        .alert("Clear My Cue Voice?", isPresented: $confirmsClear) {
            Button("Clear", role: .destructive) {
                profile.clearVoice()
                scheduler.reset()
                toast.show(String(localized: "My Cue Voice cleared. Your themes stay."))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every answer, example and what Cue learned is deleted. Your themes stay.")
        }
    }

    // MARK: - The two buttons

    private var buttons: some View {
        HStack(spacing: 8) {
            if aiStatus.isAvailable {
                Button { showsPreview = true } label: {
                    Text("✦ Preview my voice")
                        .cueFont(14, weight: .semibold)
                        .foregroundStyle(Palette.aiTextStrong)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Palette.aiFill, in: Capsule())
                        .overlay(Capsule().strokeBorder(Palette.aiBorder, lineWidth: 0.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("voicePage.preview")
            }
            Button { showsSends = true } label: {
                Text("What Cue sends")
                    .cueFont(14, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Palette.fill, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("voicePage.sends")
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { MyCueVoicePage() }
}
#endif
