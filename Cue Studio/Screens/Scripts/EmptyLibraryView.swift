//
//  EmptyLibraryView.swift
//  Cue Studio
//

import SwiftUI

/// A library with no scripts (not loading, not an empty search): one card, "Let's Cue!",
/// whose idea is answered in the card (`IdeaPromptCard`, the same one the list shows: typed or dictated in place,
/// its arrow opens Generate with AI, or the ideas from the creator's topics when nothing is written),
/// then writing and importing as quiet rows, and recording without a script as a small link. The
/// "+" in the navigation bar stays, as in every state.
struct EmptyLibraryView: View {
    var animatesPromptBackground = true
    /// Why Apple Intelligence can't write now; nil when it can.
    var unavailableReason: String?
    let onWrite: () -> Void
    let onImport: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your next video starts here.")
                        .font(.title.bold())
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Turn an idea into a script.")
                        .font(.body)
                        .foregroundStyle(Palette.ink2)
                }
                IdeaPromptCard(
                    base: Palette.surface, animatesBackground: animatesPromptBackground,
                    unavailableReason: unavailableReason
                )
                .accessibilityIdentifier("empty.promptCard")
                GroupedCard(dividerInset: 72) {
                    option(
                        title: "Write a script", detail: "Start with your own words",
                        systemImage: "pencil.line", identifier: "empty.writeButton", action: onWrite
                    )
                    option(
                        title: "Import text", detail: "Paste or choose a file",
                        systemImage: "doc.text", identifier: "empty.importButton", action: onImport
                    )
                }
                skipLink
            }
            .padding(.horizontal, Metrics.textGutter)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Pieces

    /// Recording with no script: a red dot, the words and a chevron, with no outline to compete with the card.
    private var skipLink: some View {
        Button(action: onSkip) {
            HStack(spacing: 8) {
                Circle().fill(Palette.record).frame(width: 8, height: 8)
                Text("Record without a script")
                Image(systemName: "chevron.forward").font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.ink2)
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Freestyle · Add a script anytime"))
        .accessibilityIdentifier("empty.skipButton")
    }

    private func option(
        title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String,
        identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 42, height: 42)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview {
    EmptyLibraryView(onWrite: {}, onImport: {}, onSkip: {})
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
