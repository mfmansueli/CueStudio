//
//  EmptyLibraryView.swift
//  Cue Studio
//

import SwiftUI

/// Scripts with none (not loading, not an empty search), between the large title and the dock: three ways in, as cards: **Find
/// inspiration** (ideas from the creator's topics, the sheet), **Write it yourself** (a blank page) and **Import a script**. The dock under
/// it stays the place to type or say an idea, so there is no second "write with AI" button here.
///
/// The first use has the small constellation, "How do you want to start?" and "Pick the easiest way to get your words flowing."; a creator
/// who had scripts and deleted them all (`ScriptsEmptyState.returning`) gets the same three cards under a lighter header, without the
/// illustration. Without Apple Intelligence, Find inspiration says its ideas are starters to write yourself. While the first voyage is on, a slim
/// strip above says these ways in are its first step (`VoyageStrip`).
struct EmptyLibraryView: View {
    enum Kind {
        case firstUse
        case returning
    }

    let kind: Kind
    /// Why Apple Intelligence can't write now; nil when it can.
    var unavailableReason: String?
    let onInspiration: () -> Void
    let onWrite: () -> Void
    let onImport: () -> Void

    @Environment(FirstVoyageService.self) private var voyage

    private var hasAI: Bool { unavailableReason == nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HUDLine(values: [kind == .firstUse ? String(localized: "No scripts yet") : String(localized: "No scripts right now")], tint: Palette.inkHint)
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("scripts.summary")
                voyageStep
                header
                    .padding(.top, kind == .firstUse ? 4 : 20)
                paths
                    .padding(.top, kind == .firstUse ? 22 : 20)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(kind == .firstUse ? "empty.firstUse" : "empty.returning")
    }

    // MARK: - Pieces

    /// The first voyage: a slim strip while writing is the step (the three ways in below are that step), else its card.
    @ViewBuilder
    private var voyageStep: some View {
        if voyage.showsCard {
            Group {
                if voyage.progress.current == .write {
                    VoyageStrip()
                } else {
                    VoyageCard(host: .scripts)
                }
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var header: some View {
        switch kind {
        case .firstUse:
            VStack(spacing: 0) {
                ScriptsConstellation(scale: 0.8)
                // The title starts into the constellation, as on the board (its lines run behind the words).
                title("How do you want to start?")
                    .padding(.top, -28)
                subtitle("Pick the easiest way to get your words flowing.")
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        case .returning:
            VStack(spacing: 0) {
                title("Ready for the next one?")
                subtitle("Start a new script whichever way suits you.")
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func title(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.title2.weight(.bold))
            .tracking(-0.4)
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("empty.title")
    }

    private func subtitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.ink2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)
    }

    private var paths: some View {
        VStack(spacing: 10) {
            EmptyLibraryPathCard(
                symbol: FindInspirationSheet.symbol, title: "Find inspiration",
                subtitle: hasAI ? "Discover video ideas from your topics." : "Starter ideas for your topics, to write yourself.",
                tint: .accent, action: onInspiration
            )
            .accessibilityIdentifier("empty.inspirationButton")
            EmptyLibraryPathCard(symbol: "pencil", title: "Write it yourself", subtitle: "A blank page, your words.", action: onWrite)
                .accessibilityIdentifier("empty.writeButton")
            EmptyLibraryPathCard(symbol: "doc.text", title: "Import a script", subtitle: "Bring something you already wrote.", action: onImport)
                .accessibilityIdentifier("empty.importButton")
        }
    }
}

#if DEBUG
#Preview("First use") {
    EmptyLibraryView(kind: .firstUse, onInspiration: {}, onWrite: {}, onImport: {})
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}

#Preview("Returning") {
    EmptyLibraryView(kind: .returning, onInspiration: {}, onWrite: {}, onImport: {})
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
