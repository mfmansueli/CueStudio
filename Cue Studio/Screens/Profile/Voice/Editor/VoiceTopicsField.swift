//
//  VoiceTopicsField.swift
//  Cue Studio
//

import SwiftUI

/// "What do you talk about?" (Essentials 2): up to three broad themes, the same the first flight offers, then, under each one picked, the
/// subtopics that make it specific (up to `VoiceLimits.details` each, Cue's or their own words). The owner (03/11/2026): the first flight asks
/// general themes, and here the creator says what inside them, as much as they like. The same field in the guided questions and in the editor.
struct VoiceTopicsField: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast

    @State private var typesTopic = false

    private var current: CreatorProfile { profile.profile }

    /// The themes a creator can pick, the ones their kind of creator most often talks about first (a lawyer sees Law & rights first).
    private var themes: [VoiceTopicRef] {
        let first = current.kind?.themes ?? []
        return (first + Niche.offered.filter { !first.contains($0) }).map(VoiceTopicRef.niche)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.questionGap) {
            // What they picked and what inside it first (the owner, 03/11/2026: the subtopics are what this asks once the first flight gave
            // the themes); the long list of themes, to change or add one, after them.
            if !current.topics.isEmpty { picked }
            ForEach(current.topics) { topic in subtopics(of: topic) }
            VoiceFieldSection(String(localized: "Themes")) {
                chips(themes)
                ownTopic
            }
        }
    }

    // MARK: - The topics

    private var picked: some View {
        VoiceFieldSection(String(localized: "Your topics"), detail: "\(current.topicCount) / \(VoiceLimits.topics)") {
            FlowLayout(spacing: 8, lineSpacing: 4) {
                ForEach(current.topics) { topic in
                    Button { toggle(topic) } label: {
                        FilterChip(label: topic.label + " ✕", isSelected: true, dotColor: nil)
                            .overlay(alignment: .leading) { bar(for: topic) }
                            .frame(minHeight: Metrics.hitTarget)
                            .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Remove \(topic.label)"))
                    .accessibilityIdentifier("voice.topic.picked.\(topic.id)")
                }
            }
        }
    }

    /// The bar of the world a topic is in the universe (3 × 14 pt, in the order they were picked).
    @ViewBuilder
    private func bar(for topic: VoiceTopicRef) -> some View {
        if let world = current.topics.firstIndex(of: topic) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(OnboardingTopic.color(at: world))
                .frame(width: Metrics.themeRailWidth, height: Metrics.themeRailChipHeight)
                .padding(.leading, 6)
                .accessibilityHidden(true)
        }
    }

    private func chips(_ topics: [VoiceTopicRef]) -> some View {
        FlowLayout(spacing: 8, lineSpacing: 0) {
            ForEach(topics) { topic in
                let isOn = current.topics.contains(topic)
                Button { toggle(topic) } label: {
                    FilterChip(label: topic.label, isSelected: isOn, height: 40)
                        .fixedSize()
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                        .opacity(isOn || current.topicCount < VoiceLimits.topics ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("voiceSetup.niche.\(topic.id)")
            }
        }
    }

    private func toggle(_ topic: VoiceTopicRef) {
        Haptics.selection()
        if case .limit(let message) = profile.toggleTopic(topic) { toast.show(message, kind: .problem) }
    }

    // MARK: - Their own

    @ViewBuilder
    private var ownTopic: some View {
        if typesTopic {
            VoiceTypedField(
                placeholder: String(localized: "e.g. Vegan meal prep, F1, tarot"),
                submit: { text, keeping in profile.addSomethingElse(text, for: .topics, keepingTyped: keeping) },
                identifier: "voice.topic.field"
            )
        } else {
            Button { typesTopic = true } label: {
                Text("+ Not here? Add your topic")
                    .cueFont(.body)
                    .foregroundStyle(Palette.aiText)
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("voice.topic.own")
        }
    }

    // MARK: - Subtopics

    /// More specific: the subtopics Cue suggests for a topic they picked, up to `VoiceLimits.details`, and a field for their own.
    private func subtopics(of topic: VoiceTopicRef) -> some View {
        let held = current.subtopics(of: topic)
        let suggested = topic.suggestedSubtopics
        let own = held.filter { text in !suggested.contains { $0.id == text } }
        return VoiceFieldSection(String(localized: "More specific in \(topic.label)"), detail: String(localized: "up to \(VoiceLimits.details)")) {
            VoiceOptionChips(
                options: suggested,
                isSelected: { held.contains($0.id) },
                onTap: { option in
                    if case .limit(let message) = profile.toggleSubtopic(option.id, of: topic) { toast.show(message, kind: .problem) }
                },
                extras: own,
                onTapExtra: { _ = profile.toggleSubtopic($0, of: topic) },
                identifier: "voice.subtopic.\(topic.id)"
            )
            VoiceTypedField(
                placeholder: String(localized: "Your own"),
                submit: { text, keeping in profile.addSubtopic(text, to: topic, keepingTyped: keeping) },
                identifier: "voice.subtopic.field.\(topic.id)"
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice.subtopics.\(topic.id)")
    }
}
