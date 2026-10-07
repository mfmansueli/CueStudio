//
//  MyCueVoicePage.swift
//  Cue Studio
//

import SwiftUI

/// 9.3 · My Cue Voice, the full page: what Cue uses with its switch, the meter and the next question, the three layers — Essentials (kind of creator,
/// topics, audience, why they watch, tone), Personality (style, formats, openings, endings, what the videos are for, phrases, what to avoid, reach) and
/// Proof (examples) — each row opening the one editor on its field, and, under them, **✦ Preview my voice** and **What Cue sends**. Without Apple
/// Intelligence the data stays saved and editable, and the page says the voice needs it.
struct MyCueVoicePage: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(VoiceQuestionScheduler.self) private var scheduler
    @Environment(AIStatus.self) private var aiStatus

    @State private var setup: ProfileVoiceSetup?
    @State private var editing: VoiceEditorField?
    @State private var showsPreview = false
    @State private var showsSends = false

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !aiStatus.isAvailable { needsAI }
                mainCard
                Text("What Cue tells Apple Intelligence · on device")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 16)
                buttons
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

    /// One material card, as in the Profile list (9.1): what Cue uses with its switch, the meter and the next question, then the layers as
    /// uppercase headers over rows of 52 pt or more.
    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
            ForEach(VoiceLayer.allCases, id: \.self) { layerView($0) }
        }
        .profileBlock()
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
            ForEach(VoicePageRow.rows(of: layer)) { row in
                VoicePageRowView(row: row, profile: current) { editing = VoiceEditorField(row) }
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
        Button { editing = VoiceEditorField(question.field) } label: {
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

    // MARK: - The two buttons

    private var buttons: some View {
        HStack(spacing: 8) {
            if aiStatus.isAvailable {
                Button { showsPreview = true } label: {
                    Text("✦ Preview my voice")
                        .font(.system(size: 14, weight: .semibold))
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
                    .font(.system(size: 14, weight: .semibold))
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
