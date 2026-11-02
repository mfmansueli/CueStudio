//
//  VoiceLearnedField.swift
//  Cue Studio
//

import SwiftUI

/// "What Cue learned" (the owner's item 11, 02/11/2026): what Cue learned from the creator, newest first. It shows the changes kept from "Adjust",
/// with what each one changed, and the scripts they approved or recorded. ✕ takes one back, so the next scripts don't use it.
struct VoiceLearnedField: View {
    @Environment(CreatorProfileService.self) private var profile

    private var current: CreatorProfile { profile.profile }

    private enum Item: Identifiable {
        case change(VoiceLearning)
        case sample(VoiceExample)

        var id: UUID {
            switch self {
            case .change(let learning): learning.id
            case .sample(let sample): sample.id
            }
        }

        var date: Date {
            switch self {
            case .change(let learning): learning.addedAt
            case .sample(let sample): sample.addedAt
            }
        }
    }

    private var items: [Item] {
        (current.learned.map(Item.change) + current.approvedSamples.map(Item.sample)).sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !items.isEmpty {
                GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 16) {
                    ForEach(items) { row($0) }
                }
            }
            Text(items.isEmpty
                ? "Cue learns from what you keep in Adjust and from scripts you approve."
                : "Remove one and the next scripts won’t use it.")
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
                .accessibilityIdentifier("voice.learned.note")
        }
    }

    private func row(_ item: Item) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(meta(item))
                    .hudFont()
                    .interfaceTracking(0.6)
                    .foregroundStyle(Palette.ink2)
                switch item {
                case .change(let learning):
                    Text(learning.change).cueFont(.body).foregroundStyle(Palette.ink)
                case .sample(let sample):
                    Text("“\(sample.text)”").cueFont(.subheadline).italic().foregroundStyle(Palette.ink).lineLimit(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            Button {
                withAnimation(.easeOut(duration: 0.2)) { remove(item) }
            } label: {
                Image(systemName: "xmark")
                    .cueFont(.footnote, weight: .bold)
                    .foregroundStyle(Palette.ink2)
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            }
            .accessibilityLabel(Text("Remove"))
            .accessibilityIdentifier("voice.learned.remove")
        }
        .padding(.leading, 16)
        .accessibilityIdentifier("voice.learned.item")
    }

    /// "ADJUST · TOO LONG · NOV 2", or where an approved script came from ("SOUNDS LIKE ME · NOV 2").
    private func meta(_ item: Item) -> String {
        let date = item.date.formatted(.dateTime.month(.abbreviated).day())
        let parts: [String?]
        switch item {
        case .change(let learning):
            parts = [String(localized: "Adjust"), learning.tooLongCause?.label ?? learning.kind?.label, date]
        case .sample(let sample):
            parts = [sample.source, date]
        }
        return parts.compactMap { $0 }.joined(separator: " · ").uppercased()
    }

    private func remove(_ item: Item) {
        switch item {
        case .change(let learning): profile.forget(learning)
        case .sample(let sample): profile.removeApprovedSample(sample.id)
        }
    }
}
