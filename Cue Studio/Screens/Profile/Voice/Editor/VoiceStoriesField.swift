//
//  VoiceStoriesField.swift
//  Cue Studio
//

import SwiftUI

/// "Stories and facts" (the owner's item 9, 02/11/2026): true moments of the creator's, under guided questions, said or typed. The card says what
/// they are for: real situations Cue uses as examples of how the creator talks and writes; a script may use one that fits the idea, and nothing
/// of the kind is ever invented.
struct VoiceStoriesField: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast

    @State private var asking: VoiceStory.Kind = .start

    private var stories: [VoiceStory] { profile.profile.stories }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tell real moments from your work. Cue uses them as examples of how you talk and write, and never invents others.")
                .cueFont(.subheadline)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("voice.stories.intro")
            if !stories.isEmpty {
                GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 16) {
                    ForEach(stories) { row($0) }
                }
            }
            if stories.count < VoiceStory.limit { adding }
        }
    }

    private func row(_ story: VoiceStory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(([story.kind.question, story.said ? String(localized: "Said") : nil].compactMap { $0 }).joined(separator: " · ").uppercased())
                        .hudFont()
                        .interfaceTracking(0.6)
                        .foregroundStyle(Palette.ink2)
                    Text(story.text).cueFont(.body).foregroundStyle(Palette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { profile.removeStory(story.id) }
                } label: {
                    Image(systemName: "xmark")
                        .cueFont(.footnote, weight: .bold)
                        .foregroundStyle(Palette.ink2)
                        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                }
                .accessibilityLabel(Text("Remove"))
                .accessibilityIdentifier("voice.story.remove")
            }
            if story.kind == .clientResult {
                Toggle("I may name this person", isOn: Binding(get: { story.mayName }, set: { profile.setMayName($0, story: story.id) }))
                    .cueFont(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.successText)
                    .padding(.trailing, 12)
                    .accessibilityIdentifier("voice.story.mayName")
            }
        }
        .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 4))
    }

    private var adding: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Question", selection: $asking) {
                ForEach(VoiceStory.Kind.allCases) { Text($0.question).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Palette.accText)
            .accessibilityIdentifier("voice.story.kind")
            VoiceDictationField(placeholder: String(localized: "Say it or type it"), identifier: "voice.story.field") { text, said in
                switch profile.addStory(text, kind: asking, said: said) {
                case .added: return true
                case .tooShort: toast.show(String(localized: "Tell a bit more"), kind: .problem)
                case .blocked: toast.show(VoiceTextValidator.ExampleCheck.blocked.message ?? "", kind: .problem)
                case .limit: toast.show(String(localized: "Max \(VoiceStory.limit) · tap to remove"), kind: .problem)
                }
                return false
            }
        }
    }
}
