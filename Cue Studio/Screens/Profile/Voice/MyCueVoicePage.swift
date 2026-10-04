//
//  MyCueVoicePage.swift
//  Cue Studio
//

import SwiftUI

/// 9.3 · My Cue Voice, the full page: the meter, the next question, and the three layers — Essentials (kind of creator, topics,
/// audience, tone), Personality (openings, endings, phrases, formats, swearing) and Proof (examples) — each row opening
/// its own sheet, then "What Cue sends": the brief as the model reads it. Without Apple Intelligence the data stays saved and
/// editable, and the page says the voice needs it.
struct MyCueVoicePage: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(VoiceNudgeService.self) private var nudges
    @Environment(AIStatus.self) private var aiStatus

    @State private var setup: ProfileVoiceSetup?
    @State private var personality: VoicePersonalityItem?
    @State private var showsExamples = false

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !aiStatus.isAvailable { needsAI }
                if let next = nudges.current(isAIAvailable: aiStatus.isAvailable) {
                    VoiceNudgeCard(item: next) { personality = next }
                }
                layer(title: String(localized: "Essentials"), points: essentialsPoints, of: 60) { essentials }
                layer(title: String(localized: "Personality"), points: personalityPoints, of: 25) { personalityRows }
                layer(title: String(localized: "Proof"), points: min(VoiceExample.limit, current.examples.count) * 5, of: 15) { proofRow }
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
            }
            .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
        }
        .skyBackground()
        .navigationTitle("My Cue Voice")
        .toolbarTitleDisplayMode(.inline)
        .sheet(item: $setup) { setup in
            VoiceSetupSheet(mode: setup.mode, profile: profile.profile, startAt: setup.startAt)
        }
        .sheet(item: $personality) { VoicePersonalitySheet(item: $0) }
        .sheet(isPresented: $showsExamples) { VoiceExamplesSheet() }
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

    private var essentialsPoints: Int { VoiceSetupStep.allCases.filter { current.isChosen($0) }.count * 15 }
    private var personalityPoints: Int { VoicePersonalityItem.allCases.filter { current.isFilled($0) }.count * 5 }

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

    @ViewBuilder
    private var essentials: some View {
        ForEach(Array(VoiceSetupStep.allCases.enumerated()), id: \.element) { index, step in
            row(
                title: essentialTitle(step), value: essentialValue(step), isFilled: current.isChosen(step), isFirst: index == 0,
                identifier: "voicePage.row.\(step.rawValue)"
            ) { setup = ProfileVoiceSetup(mode: .edit, startAt: step) }
        }
    }

    @ViewBuilder
    private var personalityRows: some View {
        ForEach(Array(VoicePersonalityItem.allCases.enumerated()), id: \.element) { index, item in
            row(
                title: item.title, value: current.values(for: item).joined(separator: " · "), isFilled: current.isFilled(item),
                isFirst: index == 0, identifier: "voicePage.row.\(item.rawValue)"
            ) { personality = item }
        }
    }

    private var proofRow: some View {
        row(
            title: String(localized: "Examples"),
            value: current.examples.isEmpty ? "" : String(localized: "\(current.examples.count) of \(VoiceExample.limit)"),
            isFilled: !current.examples.isEmpty, isFirst: true, identifier: "voicePage.row.examples"
        ) { showsExamples = true }
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

    private func essentialTitle(_ step: VoiceSetupStep) -> String {
        switch step {
        case .role: String(localized: "I am")
        case .niche: String(localized: "Topics")
        case .audience: String(localized: "Audience")
        case .tone: String(localized: "Voice")
        }
    }

    private func essentialValue(_ step: VoiceSetupStep) -> String {
        switch step {
        case .role: current.role?.label ?? ""
        case .niche: current.hasAnswered(.niche) ? current.niches.map(\.label).joined(separator: " · ") : ""
        case .audience: current.isChosen(.audience) ? current.vocabulary.audienceLabel : ""
        case .tone: current.isChosen(.tone) ? current.sounds.map(\.label).joined(separator: " · ") : ""
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
