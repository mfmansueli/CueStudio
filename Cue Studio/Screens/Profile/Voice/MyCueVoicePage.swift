//
//  MyCueVoicePage.swift
//  Cue Studio
//

import SwiftUI

/// 9.3 · My Cue Voice, the full page: on top of the card, a section of its own with the voice's switch and the meter as a fuel tank (the owner,
/// 03/11/2026; the next question is on the Profile's card, not here), then the sections in the creator's order
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
    /// What the tank shows while a sheet of answers is open: the strength from before it, so the ship doesn't launch at every answer; when the
    /// sheet closes, the tank catches up and the ship pours what was added once (the owner, 04/11/2026: the flight is the reward for answering).
    @State private var heldStrength: Int?
    /// The page's scroll, to bring the tank into view before it launches.
    @State private var scroll = ScrollPosition(edge: .top)
    @State private var isScrolledDown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var current: CreatorProfile { profile.profile }
    private var shownStrength: Int { heldStrength ?? current.voiceStrength }

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
        .scrollPosition($scroll)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 8
        } action: { _, scrolledDown in
            isScrolledDown = scrolledDown
        }
        .skyBackground()
        .navigationTitle("My Cue Voice")
        .toolbarTitleDisplayMode(.inline)
        .sheet(item: $setup, onDismiss: releaseStrength) { setup in
            VoiceSetupSheet(mode: setup.mode, profile: profile.profile, startAt: setup.startAt)
        }
        .sheet(item: $editing, onDismiss: releaseStrength) { VoiceEditorSheet(field: $0) }
        .onChange(of: setup != nil || editing != nil) { _, answering in
            if answering, heldStrength == nil { heldStrength = current.voiceStrength }
        }
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

    /// The voice at a glance, set apart inside the card on a raised panel (the owner, 03/11/2026): the switch named for what it does and how
    /// much Cue knows, as the spaceship's fuel tank.
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
            VoiceMeter(strength: shownStrength, level: VoiceStrengthLevel(strength: shownStrength), style: .tank)
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

    /// The sheet of answers closed: if Cue knows more, the page first glides back to the top so the tank is in view (the owner, 04/11/2026), then
    /// the meter shows what Cue knows now and the ship pours what was added (`VoiceFuelTank`); otherwise the meter simply lets go.
    private func releaseStrength() {
        guard let held = heldStrength, current.voiceStrength > held, isScrolledDown else {
            heldStrength = nil
            return
        }
        withAnimation(reduceMotion ? nil : .smooth(duration: Self.backToTop)) { scroll.scrollTo(edge: .top) }
        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : Self.backToTop))
            heldStrength = nil
        }
    }

    /// The glide back to the top before the tank launches.
    private static let backToTop: TimeInterval = 0.5

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
