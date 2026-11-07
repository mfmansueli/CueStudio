//
//  CaptionStylesTab.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Caption style › Styles: the captions' size (what most creators set right after the style; also in Format), the filters (All,
/// Favorites, Mine and the catalogue's groups, kept as left), then the cards in a grid
/// that fills the panel (three in a row on an iPhone): this video's look when no style is it, "Save style", the creator's styles
/// and the twenty of the catalogue by group. Each card is drawn by the export's renderer with this video's words; the one the
/// captions wear is checked and plays. Held (or with VoiceOver's actions), a card favors, starts new videos, saves a copy, and
/// for the creator's own renames, updates and deletes. Picking keeps the captions' size, place and format, and offers the
/// style's own.
struct CaptionStylesTab: View {
    @Bindable var viewModel: QuickEditViewModel
    let frame: UIImage?
    let samples: CaptionCardSamples
    @Binding var naming: StyleNameRequest?

    /// A card's width (`PanelPresetCard`) and the least room beside it.
    private static let cell: CGFloat = 104

    private var captions: CaptionsViewModel { viewModel.captions }

    var body: some View {
        let filter = captions.captionCatalogFilter
        let sections = captions.captionCardSections(filter)
        // How big the captions are is what most creators set right after the style: here too, not only in Format.
        PanelSegmented(
            label: String(localized: "Size"),
            options: CaptionSize.allCases.map { PanelOption($0, $0.label, key: "\($0.rawValue)") },
            selection: CaptionSize.nearest(to: captions.captionPointSize), height: 38, identifier: "edit.captionStyleSize"
        ) { captions.setCaptionPointSize($0.points) }
        PanelChips(
            options: CaptionCatalogFilter.allCases.map { PanelOption($0, $0.label, key: $0.rawValue) }, selection: filter,
            identifier: "edit.captionFilter", onSelect: captions.setCaptionCatalogFilter
        )
        ForEach(sections) { section in
            if let title = section.title {
                Text(title)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .accessibilityAddTraits(.isHeader)
            }
            grid(section.cards, savesFirst: section.isMine && viewModel.edit.captionCollection != nil)
        }
        if sections.allSatisfy(\.cards.isEmpty) { emptyNote(filter) }
        if let name = captions.captionFullStyleOffer {
            VStack(alignment: .leading, spacing: 8) {
                PanelNote(text: String(localized: "Your size, position and format stayed."))
                PanelButton(label: String(localized: "Use \(name)'s size and position"), systemImage: "arrow.uturn.backward",
                            identifier: "edit.captionStyle.full", action: captions.useFullCaptionStyle)
            }
            .accessibilityElement(children: .contain)
        }
        Color.clear.frame(height: 0)
            .task(id: sampleKey(sections)) {
                samples.prepare(sections.flatMap(\.cards), words: words)
            }
    }

    /// What the cards say (taken when the panel opened).
    private var words: [String] {
        captions.captionSampleWords.isEmpty ? captions.currentSampleWords : captions.captionSampleWords
    }

    private func sampleKey(_ sections: [CaptionsViewModel.CaptionCardSection]) -> Int {
        var hasher = Hasher()
        hasher.combine(sections.flatMap(\.cards))
        hasher.combine(words)
        return hasher.finalize()
    }

    private func grid(_ cards: [CaptionStyleCard], savesFirst: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.cell), spacing: 8, alignment: .top)], spacing: 12) {
            if savesFirst {
                PanelSaveStyleCard(identifier: "edit.captionStyle.save") {
                    naming = StyleNameRequest(purpose: .save, name: captions.suggestedCaptionStyleName)
                }
            }
            ForEach(cards) { card in cardView(card) }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.captionCatalog")
    }

    private func cardView(_ card: CaptionStyleCard) -> some View {
        PanelPresetCard(
            name: card.name, sample: samples.stills[card.id], motion: samples.motions[card.id], frame: frame, isSelected: card.isSelected,
            isFavorite: card.isFavorite, isDefault: card.isDefault, summary: card.summary, identifier: identifier(card),
            action: { captions.pickCaptionCard(card) },
            menu: { menu(card) }
        )
    }

    @ViewBuilder
    private func menu(_ card: CaptionStyleCard) -> some View {
        if let key = card.key {
            StyleCardMenu(
                isFavorite: card.isFavorite, isDefault: card.isDefault, defaultLabel: String(localized: "Use for new videos"),
                onFavorite: { captions.toggleFavoriteCaptionStyle(key) },
                onDefault: { captions.toggleDefaultCaptionStyle(key, name: card.name) },
                onDuplicate: { captions.duplicateCaptionStyle(card) },
                onRename: key.savedID.map { id in { naming = StyleNameRequest(purpose: .rename(id), name: card.name) } },
                onUpdate: key.savedID.map { id in { captions.updateCaptionStyle(id) } },
                onDelete: key.savedID.map { id in { captions.deleteCaptionStyle(id) } }
            )
        } else {
            Button(String(localized: "Save style"), systemImage: "plus") {
                naming = StyleNameRequest(purpose: .save, name: captions.suggestedCaptionStyleName)
            }
        }
    }

    private func identifier(_ card: CaptionStyleCard) -> String {
        switch card.kind {
        case .current: "edit.captionPreset.custom"
        case .builtIn(let theme): "edit.captionPreset.\(theme.rawValue)"
        case .saved: "edit.captionPreset.\(card.id)"
        }
    }

    @ViewBuilder
    private func emptyNote(_ filter: CaptionCatalogFilter) -> some View {
        switch filter {
        case .favorites: PanelNote(text: String(localized: "No favorites yet. Tap ••• on a style to add it."))
        case .mine: PanelNote(text: String(localized: "Your styles go here. Style the captions, then Save style."))
        default: EmptyView()
        }
    }
}
