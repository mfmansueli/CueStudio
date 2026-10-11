//
//  EmptyLibraryView.swift
//  Cue Studio
//

import SwiftUI

/// Scripts with none (not loading, not an empty search), between the large title and the dock: two ways in, as cards, **Write it yourself**
/// (a blank page) and **Import a script**. The dock under it stays the place to type or say an idea, and its lightbulb opens Find inspiration
/// (in every state of Scripts, so there is no inspiration card here, and no second "write with AI" button).
///
/// The first use has the small constellation, "How do you want to start?" and "Pick the easiest way to get your words flowing."; a creator
/// who had scripts and deleted them all (`ScriptsEmptyState.returning`) gets the same cards under a lighter header, without the illustration.
/// While the first voyage is on, its first tip sits above the dock (`VoyageFloatingTip`), not here.
///
/// It fits between the title and the dock without scrolling (the dock never moves): the version with the constellation when there is
/// room, without it when not, and only past that (very large text, the smallest iPhone) it scrolls.
struct EmptyLibraryView: View {
    enum Kind {
        case firstUse
        case returning
    }

    let kind: Kind
    let onWrite: () -> Void
    let onImport: () -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            content(showsConstellation: true)
            content(showsConstellation: false)
            ScrollView { content(showsConstellation: false) }
                .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // A container of its own (the scroll view was one): without it the screen's identifier lands on every button inside.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(kind == .firstUse ? "empty.firstUse" : "empty.returning")
    }

    private func content(showsConstellation: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HUDLine(values: [kind == .firstUse ? String(localized: "No scripts yet") : String(localized: "No scripts right now")], tint: Palette.inkHint)
                .padding(.horizontal, 4)
                .accessibilityIdentifier("scripts.summary")
            header(showsConstellation: showsConstellation && kind == .firstUse)
                .padding(.top, 16)
            paths
                .padding(.top, 18)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: - Pieces

    @ViewBuilder
    private func header(showsConstellation: Bool) -> some View {
        switch kind {
        case .firstUse:
            VStack(spacing: 0) {
                // Above the words, never under them (the board ran its lines behind the title, which read badly on a phone).
                if showsConstellation {
                    ScriptsConstellation(scale: 0.6)
                        .padding(.bottom, 6)
                }
                title("How do you want to start?")
                subtitle("Pick the easiest way to get your words flowing.")
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
        case .returning:
            VStack(spacing: 0) {
                title("Ready for the next one?")
                subtitle("Start a new script whichever way suits you.")
                    .padding(.top, 6)
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
            EmptyLibraryPathCard(symbol: "pencil", title: "Write it yourself", subtitle: "A blank page, your words.", action: onWrite)
                .accessibilityIdentifier("empty.writeButton")
            EmptyLibraryPathCard(symbol: "doc.text", title: "Import a script", subtitle: "Bring something you already wrote.", action: onImport)
                .accessibilityIdentifier("empty.importButton")
        }
    }
}

#if DEBUG
#Preview("First use") {
    EmptyLibraryView(kind: .firstUse, onWrite: {}, onImport: {})
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}

#Preview("Returning") {
    EmptyLibraryView(kind: .returning, onWrite: {}, onImport: {})
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
