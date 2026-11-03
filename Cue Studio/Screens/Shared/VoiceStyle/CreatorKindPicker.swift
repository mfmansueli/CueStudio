//
//  CreatorKindPicker.swift
//  Cue Studio
//

import SwiftUI

/// "What kind of creator are you?": a search over the long list of kinds (`CreatorKind.all`), and, without one, the areas they are grouped in
/// (`CreatorKindArea`) with the kinds of the one chosen: "Popular" (the kinds that cover the most creators) to begin with, or the area of the
/// kind already picked. The search keeps the kinds whose name holds what was typed (in the interface language, without minding accents or
/// case), from every area. The owner (03/11/2026): one list a lawyer, a nutritionist or a food reviewer each finds themselves in, grouped by
/// area so it is plain where to look; what comes under it (what the videos are for) stays close. My Cue Voice and Edit Profile show the same.
struct CreatorKindPicker: View {
    /// The id of the kind picked, if any.
    let selected: String?
    let onPick: (CreatorKind) -> Void
    /// Accessibility identifier prefix: `<prefix>.<kind id>`, `<prefix>.area.<area id>`.
    var identifier = "creatorKind"
    /// How far the row of areas reaches past the picker on each side: to the screen's edges, where the screen's gutter is.
    var bleed: CGFloat = Metrics.gutter

    @State private var search = ""
    /// The area whose kinds are shown; nil: the popular ones.
    @State private var area: CreatorKindArea?
    @State private var choseArea = false
    @FocusState private var isSearching: Bool

    /// The kinds shown as popular: the ones that cover the most creators.
    private static let popularCount = 16

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The kinds under the areas: the search's matches, or the area's (the popular ones without one).
    private var shown: [CreatorKind] {
        if !query.isEmpty {
            return CreatorKind.all.filter { $0.title.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
        return currentArea?.kinds ?? Array(CreatorKind.all.prefix(Self.popularCount))
    }

    /// The area chosen, or, until one is, the area of the kind picked (it opens where the creator is).
    private var currentArea: CreatorKindArea? {
        if choseArea { return area }
        return CreatorKind.find(selected).flatMap { kind in
            CreatorKind.all.prefix(Self.popularCount).contains { $0.id == kind.id } ? nil : CreatorKindArea.of(kind)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SearchField(text: $search, prompt: "Search: lawyer, chef, gamer…", isFocused: $isSearching)
                .accessibilityIdentifier("\(identifier).search")
            if query.isEmpty { areas }
            let kinds = shown
            if kinds.isEmpty {
                Text("None with that name. Add yours below.")
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 4)
            }
            FlowLayout(spacing: 8, lineSpacing: 4) {
                ForEach(kinds) { kind in chip(kind) }
            }
            .animation(.smooth(duration: 0.25), value: currentArea)
        }
    }

    // MARK: - Areas

    /// "Popular" and the areas, each with its symbol, in a row that scrolls sideways (as Find inspiration's topics), smaller than the kinds: they
    /// choose what is listed under them, which stays in sight right below.
    private var areas: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Browse by area")
                .cueFont(.footnote, weight: .semibold)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        areaChip(nil)
                        ForEach(CreatorKindArea.allCases) { areaChip($0) }
                    }
                    .padding(.horizontal, bleed)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -bleed)
                .onChange(of: currentArea) { _, area in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(area?.rawValue ?? "popular", anchor: .center) }
                }
                .onAppear { proxy.scrollTo(currentArea?.rawValue ?? "popular", anchor: .center) }
            }
        }
    }

    private func areaChip(_ chosen: CreatorKindArea?) -> some View {
        let isOn = currentArea == chosen
        return Button {
            Haptics.selection()
            choseArea = true
            area = chosen
        } label: {
            FilterChip(
                label: chosen?.title ?? String(localized: "Popular"), isSelected: isOn, systemImage: chosen?.systemImage ?? "star", height: 32
            )
            .frame(minHeight: Metrics.hitTarget)
            .fixedSize()
        }
        .buttonStyle(.cuePress)
        .id(chosen?.rawValue ?? "popular")
        .accessibilityIdentifier("\(identifier).area.\(chosen?.rawValue ?? "popular")")
    }

    // MARK: - Kinds

    private func chip(_ kind: CreatorKind) -> some View {
        let isOn = kind.id == selected
        return Button {
            Haptics.selection()
            isSearching = false
            onPick(kind)
        } label: {
            // The kind picked in the creator's accent, so it reads apart from the area chosen above it.
            Label {
                Text(kind.title)
            } icon: {
                if isOn { Image(systemName: "checkmark").cueFont(.footnote, weight: .bold) }
            }
            .labelStyle(KindChipLabelStyle(isOn: isOn))
        }
        .buttonStyle(.cuePress)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier("\(identifier).\(kind.id)")
    }
}

/// A kind of creator as a chip: the app's grey, or, picked, the accent's soft fill with its border and a ✓ (the state in shape too).
private struct KindChipLabelStyle: LabelStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            configuration.title
        }
        .cueFont(.subheadline, weight: isOn ? .semibold : .medium)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(isOn ? Palette.accText : Palette.ink)
        .padding(.horizontal, 14)
        .frame(height: Metrics.chipHeight)
        .background(isOn ? Palette.accSoft : Palette.surface2, in: Capsule())
        .overlay(Capsule().strokeBorder(isOn ? Palette.acc : Color.clear, lineWidth: 1.5))
        .frame(minHeight: Metrics.hitTarget)
        .contentShape(Capsule())
        .fixedSize()
    }
}
