//
//  EmptyLibraryView.swift
//  Cue Studio
//

import SwiftUI

/// A library with no scripts (not loading, not an empty search): one question, "What's the idea?",
/// answered right in the card, then writing and importing as quiet rows, and recording without a
/// script as a small link. The "+" in the navigation bar stays, as in every state, and keeps
/// Generate, Themes and Formats.
struct EmptyLibraryView: View {
    var animatesPromptBackground = true
    /// Why Apple Intelligence can't write now; nil when it can.
    var unavailableReason: String?
    /// The idea, and the kind of video picked with it, sent to the generation flow.
    let onSubmit: (ScriptIdeaSeed) -> Void
    let onWrite: () -> Void
    let onImport: () -> Void
    let onSkip: () -> Void

    @State private var draft = IdeaPromptDraft()

    var body: some View {
        ScrollViewReader { proxy in
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
                        draft: $draft, base: Palette.surface, animatesBackground: animatesPromptBackground,
                        unavailableReason: unavailableReason
                    ) {
                        if let seed = draft.seed { onSubmit(seed) }
                    }
                    .id(Self.cardID)
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
            // Typing or picking a kind of video keeps the field, the arrow and the chips in view.
            .onChange(of: draft.idea) { _, _ in withAnimation { proxy.scrollTo(Self.cardID, anchor: .center) } }
        }
    }

    private static let cardID = "ideaCard"

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
        .accessibilityHint(Text("Freestyle now — add a script anytime from the camera."))
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
    EmptyLibraryView(onSubmit: { _ in }, onWrite: {}, onImport: {}, onSkip: {})
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
