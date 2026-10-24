//
//  CoverStudioViewModel+Library.swift
//  Cue Studio
//

import Foundation

/// The creator's saved cover styles (`StyleLibrary` of `CoverStyle`: the look, never the words or the picture), managed like
/// their caption and text styles: saved with a name from Finish, put on this cover from Template (its words, picture and
/// graphics stay), renamed, updated with this cover's look, duplicated, favored, picked as the one new covers start in and
/// deleted with Undo. A cover keeps its own look: none of this changes a cover already made.
extension CoverStudioViewModel {
    var suggestedCoverStyleName: String { coverStyles.nextName() }

    /// "Save style": this cover's look, named, for the next covers.
    func saveCoverStyle(named name: String) {
        let style = coverStyles.add(composition.style, named: name)
        writeCoverStyles()
        scheduleThumbnails()
        toast.show(String(localized: "Saved as \(style.name)"))
    }

    /// A saved style on this cover (one undo step): its words, picture and graphics stay.
    func applySavedCoverStyle(_ id: UUID) {
        guard let saved = coverStyles.style(id) else { return }
        Haptics.selection()
        changeComposition { composition in
            composition = saved.look.apply(to: composition)
        }
    }

    /// The saved style this cover looks like now; nil when none.
    var wornCoverStyleID: UUID? {
        let worn = composition.style.comparable
        return coverStyles.styles.first { $0.look.comparable == worn }?.id
    }

    func renameCoverStyle(_ id: UUID, to name: String) {
        coverStyles.rename(id, to: name)
        writeCoverStyles()
    }

    /// The saved style takes this cover's look; covers already made keep theirs.
    func updateCoverStyle(_ id: UUID) {
        guard let style = coverStyles.style(id) else { return }
        coverStyles.update(id, with: composition.style)
        writeCoverStyles()
        scheduleThumbnails()
        toast.show(String(localized: "\(style.name) updated · Videos already made keep theirs"))
    }

    /// A template, drawn as this cover would be in it, saved as the creator's own style.
    func duplicateCoverTemplate(_ template: CoverTemplate) {
        let look = (composition.template == template ? composition : composition.applying(template, title: cover.title, handle: handle)).style
        let style = coverStyles.add(look, named: template.label)
        writeCoverStyles()
        scheduleThumbnails()
        toast.show(String(localized: "Saved as \(style.name)"))
    }

    func duplicateCoverStyle(_ id: UUID) {
        guard let copy = coverStyles.duplicate(id) else { return }
        writeCoverStyles()
        scheduleThumbnails()
        toast.show(String(localized: "Saved as \(copy.name)"))
    }

    func toggleFavoriteCoverStyle(_ key: StyleKey) {
        coverStyles.toggleFavorite(key)
        writeCoverStyles()
    }

    /// New covers start in `key`; picked again, Cue's own start.
    func toggleDefaultCoverStyle(_ key: StyleKey, name: String) {
        let isDefault = coverStyles.isDefault(key)
        coverStyles.setDefault(isDefault ? nil : key)
        writeCoverStyles()
        toast.show(isDefault ? String(localized: "New covers start in Cue's template") : String(localized: "New covers start in \(name)"))
    }

    func deleteCoverStyle(_ id: UUID) {
        guard let removal = coverStyles.remove(id) else { return }
        writeCoverStyles()
        toast.show(
            String(localized: "\(removal.style.name) deleted"),
            action: ToastAction(title: String(localized: "Undo")) { [weak self] in
                self?.coverStyles.restore(removal)
                self?.writeCoverStyles()
            }
        )
    }
}
