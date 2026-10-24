//
//  CaptionsViewModel+Catalog.swift
//  Cue Studio
//

import Foundation

/// Caption style › Styles: the catalogue (`CaptionTheme.catalog`) and the creator's saved styles as cards, filtered (the filter
/// kept as it was left), the one the captions wear marked, and this video's own look first when no card is it. Picking a card
/// changes the look and the motion, never where the captions sit, how big they are or how they are cut; a note then offers the
/// style's own size and place.
extension CaptionsViewModel {
    /// A group of cards under a title (nil: no title).
    struct CaptionCardSection: Identifiable {
        let title: String?
        let cards: [CaptionStyleCard]
        /// The creator's own styles: "Save style" comes first in it.
        var isMine = false

        var id: String { title ?? (isMine ? "mine" : "untitled") }
    }

    /// The words the cards say: the start of the line at the playhead (or the first line), up to four short words, so each
    /// style is seen with this video's own words, in its language and writing; without captions, a sentence in their language.
    var currentSampleWords: [String] {
        let lines = editedCaptionLines
        let time = player.currentTime
        if let line = lines.first(where: { $0.start <= time && time < $0.end }) ?? lines.first {
            var words = Array(CaptionText.words(in: line.text).prefix(4))
            while words.count > 2, CaptionText.length(words) > 22 { words.removeLast() }
            if !words.isEmpty, CaptionText.length(words) <= 28 { return words }
        }
        let sample = String(localized: "Make it real, one take", writtenIn: edit.captionLanguage,
                            comment: "What the caption style cards say when a video has no captions yet: four to five short words")
        return CaptionText.words(in: sample)
    }

    func setCaptionCatalogFilter(_ filter: CaptionCatalogFilter) {
        captionCatalogFilter = filter
        captionCatalogOffset = 0
        styles.captionCatalogFilter = filter.rawValue
    }

    /// The look the captions have now, without where they sit (nil: no collection).
    private var wornLook: CaptionSettings? {
        if let settings = edit.captionCollection { return settings.look }
        return nil
    }

    /// The one card the captions wear, when one does: the card just picked or saved while its look is still theirs, else the
    /// saved style they were put in, else the catalogue's style with their look, else the first saved style with it. Never two
    /// (a saved copy of a style looks like it).
    private var wornCard: CaptionStyleCard.Kind? {
        guard let worn = wornLook else { return nil }
        switch lastPickedCaptionCard {
        case .saved(let id)? where captionStyles.style(id)?.look.settings.look == worn: return .saved(id)
        case .builtIn(let theme)? where CaptionSettings(theme: theme).look == worn: return .builtIn(theme)
        default: break
        }
        if let id = edit.captionCollection?.savedStyleID, captionStyles.style(id)?.look.settings.look == worn { return .saved(id) }
        if let theme = CaptionTheme.catalog.first(where: { CaptionSettings(theme: $0).look == worn }) { return .builtIn(theme) }
        return captionStyles.styles.first { $0.look.settings.look == worn }.map { .saved($0.id) }
    }

    private func card(_ theme: CaptionTheme, worn: CaptionStyleCard.Kind?) -> CaptionStyleCard {
        let key = StyleKey.builtIn(theme.rawValue)
        return CaptionStyleCard(
            kind: .builtIn(theme), name: theme.label, summary: theme.summary, settings: CaptionSettings(theme: theme), isSelected: worn == .builtIn(theme),
            isFavorite: captionStyles.isFavorite(key), isDefault: captionStyles.isDefault(key)
        )
    }

    private func card(_ style: SavedStyle<MyCaptionStyle>, worn: CaptionStyleCard.Kind?) -> CaptionStyleCard {
        CaptionStyleCard(
            kind: .saved(style.id), name: style.name, summary: style.look.settings.theme.summary, settings: style.look.settings,
            isSelected: worn == .saved(style.id), isFavorite: captionStyles.isFavorite(style.key), isDefault: captionStyles.isDefault(style.key)
        )
    }

    /// This video's look, when no card of the catalogue or of the creator's is it.
    var currentCaptionCard: CaptionStyleCard? {
        let settings: CaptionSettings
        if let collection = edit.captionCollection {
            guard wornCard == nil else { return nil }
            settings = collection
        } else {
            // Captions from before the collection: their type look, drawn as the text renderer draws it (no motion).
            var legacy = CaptionSettings()
            legacy.customLook = edit.captionLook ?? TypePreset.cue.look(for: .caption)
            legacy.motion = nil
            settings = legacy
        }
        return CaptionStyleCard(
            kind: .current, name: String(localized: "This video"), summary: String(localized: "How this video's captions look now"),
            settings: settings, isSelected: true, isFavorite: false, isDefault: false
        )
    }

    /// The cards `filter` shows, grouped: in All, this video's look, the creator's styles and every group of the catalogue.
    func captionCardSections(_ filter: CaptionCatalogFilter) -> [CaptionCardSection] {
        let worn = wornCard
        let mine = captionStyles.styles.map { card($0, worn: worn) }
        let card = { (theme: CaptionTheme) in self.card(theme, worn: worn) }
        switch filter {
        case .all:
            var sections: [CaptionCardSection] = []
            if let current = currentCaptionCard { sections.append(CaptionCardSection(title: nil, cards: [current])) }
            sections.append(CaptionCardSection(title: CaptionCatalogFilter.mine.label, cards: mine, isMine: true))
            sections += CaptionCategory.allCases.map { category in
                CaptionCardSection(title: category.label, cards: CaptionTheme.themes(in: category).map(card))
            }
            return sections
        case .favorites:
            let cards = mine.filter(\.isFavorite) + CaptionTheme.catalog.map(card).filter(\.isFavorite)
            return [CaptionCardSection(title: nil, cards: cards)]
        case .mine:
            return [CaptionCardSection(title: nil, cards: mine, isMine: true)]
        case .category(let category):
            return [CaptionCardSection(title: nil, cards: CaptionTheme.themes(in: category).map(card))]
        }
    }

    /// A card tapped: its look on every line, in one undo step (this video's own look is already on).
    func pickCaptionCard(_ card: CaptionStyleCard) {
        switch card.kind {
        case .current: return
        case .builtIn(let theme): pickCaptionTheme(theme)
        case .saved(let id): applySavedCaptionStyle(id)
        }
    }

    /// A style of the catalogue on every line (one undo step): its look and its motion, keeping where the captions sit, how big,
    /// how wide, how aligned and how they are cut, and the words marked for emphasis.
    func pickCaptionTheme(_ theme: CaptionTheme) {
        guard isReady, wornLook != CaptionSettings(theme: theme).look else { return }
        let aspect = edit.aspect
        let margins = captionSafeMargins
        change { snapshot in
            let before = snapshot.captionCollection
            var next = before?.restyled(theme) ?? CaptionSettings(theme: theme)
            if before == nil { next.safeMargins = margins }
            snapshot.captionCollection = next
            snapshot.captionAnimation = next.motion?.nearestAnimation ?? .line
            Self.refit(&snapshot, from: before, aspect: aspect)
        }
        lastPickedCaptionCard = .builtIn(theme)
        previewCurrentCaptionLine()
        toast.show(String(localized: "\(theme.label) on the captions"))
    }

    // MARK: - The style's own layout

    /// The style last picked and its name, while the captions sit elsewhere than it would put them (another size, place,
    /// width or alignment, or a saved style's format): Styles offers its own.
    var captionFullStyleOffer: String? {
        guard let picked = lastPickedCaptionCard, let current = edit.captionCollection else { return nil }
        switch picked {
        case .builtIn(let theme):
            guard current.theme == theme, current.look == CaptionSettings(theme: theme).look else { return nil }
            // The style's own place is the bottom.
            return current.sitsLike(CaptionSettings(theme: theme)) && edit.captionPosition == .bottom ? nil : theme.label
        case .saved(let id):
            guard let saved = captionStyles.style(id), current.look == saved.look.settings.look else { return nil }
            let sits = current.sitsLike(saved.look.settings) && (saved.look.settings.format == nil || saved.look.settings.format == current.format)
            return sits ? nil : saved.name
        case .current:
            return nil
        }
    }

    /// "Use its size and place": the last picked style whole, its layout too (one undo step).
    func useFullCaptionStyle() {
        guard let picked = lastPickedCaptionCard else { return }
        switch picked {
        case .builtIn(let theme):
            let aspect = edit.aspect
            change { snapshot in
                guard let before = snapshot.captionCollection else { return }
                snapshot.captionCollection = before.restyled(theme, full: true)
                snapshot.captionPosition = .bottom
                Self.refit(&snapshot, from: before, aspect: aspect)
            }
        case .saved(let id):
            applySavedCaptionStyle(id, full: true)
        case .current:
            return
        }
        previewCurrentCaptionLine()
    }
}
