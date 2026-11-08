//
//  CaptionStylesTab.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Caption style › Styles: the captions' size on one short row (what most creators set right after the style; the whole layout
/// is in Layout), the filters (All, Favorites, Mine and the catalogue's groups, kept as left), then the cards in a grid that fills
/// the panel (three in a row on an iPhone), a row of them in the first view: this video's look when no style is it, the creator's
/// styles once there is one, and the twenty of the catalogue by group, "Save style" last (Mine's last card, or All's while Mine
/// is empty). Each card is drawn by the export's renderer with this video's words; the one the captions wear is checked and
/// plays. Held (or with VoiceOver's actions), a card favors, starts new videos, saves a copy, and for the creator's own renames,
/// updates and deletes. Picking keeps the captions' size, place and format, and offers the style's own.
struct CaptionStylesTab: View {
    @Bindable var viewModel: QuickEditViewModel
    let frame: UIImage?
    let samples: CaptionCardSamples
    @Binding var naming: StyleNameRequest?
    @Environment(\.dynamicTypeSize) private var typeSize

    /// A card's width (`PanelPresetCard`) and the least room beside it.
    private static let cell: CGFloat = 104

    private var captions: CaptionsViewModel { viewModel.captions }

    var body: some View {
        let filter = captions.captionCatalogFilter
        let sections = captions.captionCardSections(filter)
        sizeRow
        PanelChips(
            options: CaptionCatalogFilter.allCases.map { PanelOption($0, $0.label, key: $0.rawValue) }, selection: filter,
            identifier: "edit.captionFilter", onSelect: captions.setCaptionCatalogFilter
        )
        ForEach(sections) { section in
            VStack(alignment: .leading, spacing: 10) {
                if let title = section.title {
                    Text(title)
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                        .accessibilityAddTraits(.isHeader)
                }
                grid(section.cards, savesLast: section.endsWithSave && viewModel.edit.captionCollection != nil)
            }
            // Where Styles opens when this section has the style the captions wear (`captionRevealedSection`).
            .id(Self.sectionID(section.id))
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

    /// The id a section's title and cards scroll to (`EditorPanelContainer.revealID`).
    static func sectionID(_ section: String) -> String { "captionStyle.section.\(section)" }

    /// How big the captions are, the one layout choice most creators make right after the style: "Size" and S · M · L · XL on one
    /// row, so the cards still show in the first view (owner, canvas 2 F2; Layout has it with the rest of the layout). With large
    /// text the name goes over the choices.
    private var sizeRow: some View {
        let segmented = PanelSegmented(
            options: CaptionSize.allCases.map { PanelOption($0, $0.label, key: "\($0.rawValue)") },
            selection: CaptionSize.nearest(to: captions.captionPointSize), height: 32, identifier: "edit.captionStyleSize"
        ) { captions.setCaptionPointSize($0.points) }
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    PanelRowLabel(label: String(localized: "Size"))
                    segmented
                }
            } else {
                HStack(spacing: 16) {
                    PanelRowLabel(label: String(localized: "Size")).fixedSize()
                    segmented
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Size"))
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

    private func grid(_ cards: [CaptionStyleCard], savesLast: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.cell), spacing: 8, alignment: .top)], spacing: 12) {
            ForEach(cards) { card in cardView(card) }
            if savesLast {
                PanelSaveStyleCard(identifier: "edit.captionStyle.save") {
                    naming = StyleNameRequest(purpose: .save, name: captions.suggestedCaptionStyleName)
                }
            }
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
