//
//  VoiceTopicsField.swift
//  Cue Studio
//

import SwiftUI

/// "What do you talk about?" (Essentials 2): up to three topics out of twenty-five, then, under each one picked, the subtopics that make it
/// specific (up to three each, or their own words). The ten of the first flight come first; the fifteen only My Cue Voice offers are not worlds in the
/// universe. The same field in the guided questions and in the editor.
struct VoiceTopicsField: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast

    @State private var typesTopic = false

    private var current: CreatorProfile { profile.profile }

    /// The topics a creator can pick: the ten of the first flight, the fifteen of the voice, and any other one they already hold.
    private var popular: [VoiceTopicRef] {
        Niche.allCases.filter { Niche.offered.contains($0) || current.niches.contains($0) }.map(VoiceTopicRef.niche)
    }

    private var more: [VoiceTopicRef] { VoiceTopic.allCases.map(VoiceTopicRef.extra) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !current.topics.isEmpty { picked }
            section(String(localized: "Popular"), topics: popular)
            section(String(localized: "More"), topics: more)
            ownTopic
            ForEach(current.topics) { topic in subtopics(of: topic) }
        }
    }

    // MARK: - The topics

    private var picked: some View {
        VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(String(localized: "Your topics"), detail: "\(current.topicCount) / \(VoiceLimits.topics)")
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

    /// The bar of the world a topic is in the universe (3 × 14 pt, in the order they were picked); a topic only the voice offers has no world, so none.
    @ViewBuilder
    private func bar(for topic: VoiceTopicRef) -> some View {
        if let world = worldIndex(of: topic) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(OnboardingTopic.color(at: world))
                .frame(width: Metrics.themeRailWidth, height: Metrics.themeRailChipHeight)
                .padding(.leading, 6)
                .accessibilityHidden(true)
        }
    }

    /// The place of a topic among the worlds of the universe (the ten and the typed ones, in order), or nil when it isn't one.
    private func worldIndex(of topic: VoiceTopicRef) -> Int? {
        let worlds = current.topics.filter { if case .extra = $0 { false } else { true } }
        return worlds.firstIndex(of: topic)
    }

    private func section(_ title: String, topics: [VoiceTopicRef]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VoiceFieldLabel(title)
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
    }

    private func toggle(_ topic: VoiceTopicRef) {
        Haptics.selection()
        if case .limit(let message) = profile.toggleTopic(topic) { toast.show(message) }
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
                    .font(.body)
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

    /// More specific: the subtopics Cue suggests for a topic they picked, up to three, and a field for their own.
    private func subtopics(of topic: VoiceTopicRef) -> some View {
        let held = current.subtopics(of: topic)
        let suggested = topic.suggestedSubtopics
        let own = held.filter { text in !suggested.contains { $0.id == text } }
        return VStack(alignment: .leading, spacing: 10) {
            VoiceFieldLabel(String(localized: "More specific in \(topic.label)"), detail: String(localized: "up to \(VoiceLimits.details)"))
            VoiceOptionChips(
                options: suggested,
                isSelected: { held.contains($0.id) },
                onTap: { option in
                    if case .limit(let message) = profile.toggleSubtopic(option.id, of: topic) { toast.show(message) }
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
        .padding(14)
        .background(Palette.surface2.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice.subtopics.\(topic.id)")
    }
}
