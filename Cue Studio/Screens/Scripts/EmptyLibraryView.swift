//
//  EmptyLibraryView.swift
//  Cue Studio
//

import SwiftUI

/// Scripts with none (v30 · 3.1, not loading, not an empty search): "NO SCRIPTS YET" under the large title, the empty-state mark
/// with "Every universe starts with an idea." (the AI dock is fixed at the bottom, as on the list), three ideas from
/// the creator's topics (tap one and it is written; the star rises like for any idea), and two quiet ways in: "Write my
/// own ›" and "Import ›". Without Apple Intelligence an idea says "Write it" and opens a blank draft with the idea as its
/// title. "Record without a script" stays as a small link: the "+" in the bar has it too.
struct EmptyLibraryView: View {
    /// Why Apple Intelligence can't write now; nil when it can.
    var unavailableReason: String?
    let onWrite: () -> Void
    let onImport: () -> Void
    let onSkip: () -> Void

    @Environment(CreatorProfileService.self) private var profile
    @Environment(PresentationService.self) private var presentation
    @Environment(ScriptStarter.self) private var starter
    @Environment(IdeaTransitionService.self) private var transition
    /// Where each idea's arrow is on the screen, for its star to leave from.
    @State private var arrowCenters: [String: CGPoint] = [:]

    private var hasAI: Bool { unavailableReason == nil }

    private var ideas: [ThemeIdea] {
        Array(ThemeCatalog.page(for: profile.profile.niches, rotation: 0).prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HUDLine(values: [String(localized: "No scripts yet")], tint: Palette.ink.opacity(0.55))
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("scripts.summary")
                invitation
                    .padding(.top, 8)
                ideaList
                    .padding(.top, 30)
                links
                    .padding(.top, 4)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Pieces

    /// The mark, "Every universe starts with an idea." (22 / 28, bold) and one line under it (14, 62%).
    private var invitation: some View {
        VStack(spacing: 0) {
            ScriptsConstellation()
            // The title starts 46 pt into the constellation, as on the board (the lines run behind the words).
            Text("Every universe starts with an idea.")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.44)
                .lineSpacing(3)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, -46)
                .accessibilityAddTraits(.isHeader)
            Text(hasAI ? "One line is enough. Cue writes it in your voice." : "One line is enough to start a draft.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
    }

    private var ideaList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if hasAI { Text(verbatim: "✦") }
                Text(hasAI ? "Ideas for you · Tap to start" : "Ideas for you")
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(hasAI ? Palette.aiText : Palette.inkHint)
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
            ForEach(ideas) { idea in ideaRow(idea) }
        }
    }

    private func ideaRow(_ idea: ThemeIdea) -> some View {
        let index = profile.profile.niches.firstIndex(of: idea.niche) ?? 0
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button { start(idea) } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(OnboardingTopic.color(at: index)).frame(width: 3, height: 26)
                Text(idea.title)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if hasAI {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.aiText)
                        .frame(width: 24, height: 24)
                        .onGeometryChange(for: CGPoint.self) { proxy in
                            let frame = proxy.frame(in: .global)
                            return CGPoint(x: frame.midX, y: frame.midY)
                        } action: { arrowCenters[idea.id] = $0 }
                } else {
                    Text("Write it")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 46)
            .background(Palette.surface, in: shape)
            .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(transition.isActive)
        .accessibilityLabel(Text(idea.title))
        .accessibilityHint(Text(hasAI ? "Writes it in your voice." : "Opens a blank draft with this title."))
        .accessibilityIdentifier("empty.idea.\(idea.id)")
    }

    /// "Write my own ›" and "Import ›". Recording without a script is in "+".
    private var links: some View {
        HStack(spacing: 18) {
            link("Write my own", identifier: "empty.writeButton", action: onWrite)
            link("Import", identifier: "empty.importButton", action: onImport)
        }
        .frame(maxWidth: .infinity)
    }

    private func link(_ title: LocalizedStringKey, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(Text(title)) ›")
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(Palette.ink.opacity(0.75))
                .padding(.horizontal, 6)
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Actions

    /// With Apple Intelligence, the star rises and the idea is written; without it, a draft opens with the idea as its title.
    private func start(_ idea: ThemeIdea) {
        guard hasAI else {
            starter.writeByHand(idea: idea.title)
            return
        }
        Haptics.medium()
        starter.write(idea: idea.prompt, length: idea.length, from: arrowCenters[idea.id])
    }
}

#if DEBUG
#Preview {
    EmptyLibraryView(onWrite: {}, onImport: {}, onSkip: {})
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
