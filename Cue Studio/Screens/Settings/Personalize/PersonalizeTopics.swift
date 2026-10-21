//
//  PersonalizeTopics.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Personalize › Your topics: the creator's topics as chips in the colours they have in Scripts and in the universe, Edit (the
/// topics are My Cue Voice's, edited in its sheet), and whether Cue tags new scripts with one by itself.
struct PersonalizeTopics: View {
    @Environment(TopicTaggingService.self) private var tagging
    @Environment(PersonalizationService.self) private var personalization

    @State private var isEditing = false

    var body: some View {
        @Bindable var personalization = personalization
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                FlowLayout(spacing: 8) {
                    ForEach(Array(tagging.topics.enumerated()), id: \.offset) { index, topic in
                        chip(topic.label, color: OnboardingTopic.color(at: index))
                    }
                    if tagging.topics.isEmpty {
                        Text("No topics yet").font(.subheadline).foregroundStyle(Palette.ink2)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    Haptics.light()
                    isEditing = true
                } label: {
                    Text("Edit").font(.body.weight(.semibold)).foregroundStyle(Palette.accText).frame(minHeight: Metrics.hitTarget)
                }
                .buttonStyle(.cuePress)
                .accessibilityIdentifier("settings.topics")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Divider().overlay(Palette.separator).padding(.leading, 16)
            Toggle(isOn: $personalization.autoTagsTopics) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tag new scripts automatically").foregroundStyle(Palette.ink)
                    Text("Cue picks the topic on this iPhone").font(.footnote).foregroundStyle(Palette.ink2)
                }
            }
            .tint(Palette.success)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .accessibilityIdentifier("settings.autoTag")
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.groupedListRadius, style: .continuous))
        .sheet(isPresented: $isEditing) { VoiceEditorSheet(field: .topics) }
    }

    private func chip(_ label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.subheadline).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(color.opacity(0.16), in: Capsule())
    }
}
