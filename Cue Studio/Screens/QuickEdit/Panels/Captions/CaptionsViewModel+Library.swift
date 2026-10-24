//
//  CaptionsViewModel+Library.swift
//  Cue Studio
//

import Foundation

/// The creator's saved caption styles (`StyleLibrary` of `MyCaptionStyle`), like their texts' and covers': saved with a name
/// from Caption style › Styles, renamed, updated with the captions' look now, duplicated, favored, picked as the one new captions
/// start in, and deleted with Undo. Each video keeps its own copy of what it wears, so none of this changes a video already made.
extension CaptionsViewModel {
    /// The name "Save style" suggests: "My style", "My style 2"…
    var suggestedCaptionStyleName: String { captionStyles.nextName() }

    /// Keeps the captions' combination now (look and layout) as a style named `name`.
    func saveCaptionStyle(named name: String) {
        guard let combination = MyCaptionStyle(of: edit) else { return }
        let style = captionStyles.add(combination, named: name)
        writeCaptionStyles()
        toast.show(String(localized: "Saved as \(style.name)"))
    }

    func renameCaptionStyle(_ id: UUID, to name: String) {
        captionStyles.rename(id, to: name)
        writeCaptionStyles()
    }

    /// The saved style takes the captions' combination now; videos already made keep the look they have.
    func updateCaptionStyle(_ id: UUID) {
        guard let combination = MyCaptionStyle(of: edit), let style = captionStyles.style(id) else { return }
        captionStyles.update(id, with: combination)
        writeCaptionStyles()
        toast.show(String(localized: "\(style.name) updated · Videos already made keep theirs"))
    }

    /// A copy of a saved style, or one of Cue's saved as the creator's own (with these captions' size, place and format).
    func duplicateCaptionStyle(_ card: CaptionStyleCard) {
        switch card.kind {
        case .saved(let id):
            guard let copy = captionStyles.duplicate(id) else { return }
            writeCaptionStyles()
            toast.show(String(localized: "Saved as \(copy.name)"))
        case .builtIn, .current:
            guard let current = edit.captionCollection else { return }
            var settings = card.settings.laidOut(like: current)
            settings.safeMargins = current.safeMargins
            let animation = settings.motion?.nearestAnimation ?? edit.captionAnimation
            let style = captionStyles.add(MyCaptionStyle(settings: settings, animation: animation), named: card.name)
            writeCaptionStyles()
            toast.show(String(localized: "Saved as \(style.name)"))
        }
    }

    func toggleFavoriteCaptionStyle(_ key: StyleKey) {
        captionStyles.toggleFavorite(key)
        writeCaptionStyles()
    }

    /// New captions start in `key`; picked again, they go back to Cue's own start.
    func toggleDefaultCaptionStyle(_ key: StyleKey, name: String) {
        let isDefault = captionStyles.isDefault(key)
        captionStyles.setDefault(isDefault ? nil : key)
        writeCaptionStyles()
        toast.show(isDefault ? String(localized: "New captions start in Cue") : String(localized: "New captions start in \(name)"))
    }

    /// Deletes a saved style; the toast's Undo puts it back as it was. Videos that wear it keep their look.
    func deleteCaptionStyle(_ id: UUID) {
        guard let removal = captionStyles.remove(id) else { return }
        writeCaptionStyles()
        toast.show(
            String(localized: "\(removal.style.name) deleted"),
            action: ToastAction(title: String(localized: "Undo")) { [weak self] in
                self?.captionStyles.restore(removal)
                self?.writeCaptionStyles()
            }
        )
    }

    func writeCaptionStyles() {
        styles.captionStyles = captionStyles
    }

    // MARK: - Wearing a saved style

    /// A saved style's look on every line (one undo step), keeping where the captions sit, how big and how they are cut, like
    /// any other style; `full` takes its size, place, width, alignment and format too.
    func applySavedCaptionStyle(_ id: UUID, full: Bool = false) {
        guard isReady, let saved = captionStyles.style(id) else { return }
        let aspect = edit.aspect
        change { snapshot in
            let before = snapshot.captionCollection
            var next = saved.look.settings
            if let before, !full { next = next.laidOut(like: before) }
            next.safeMargins = before?.safeMargins ?? captionSafeMargins
            if next.format == nil { next.format = before?.format }
            next.savedStyleID = id
            snapshot.captionCollection = next
            snapshot.captionAnimation = next.motion?.nearestAnimation ?? saved.look.animation
            Self.refit(&snapshot, from: before, aspect: aspect)
        }
        lastPickedCaptionCard = .saved(id)
        previewCurrentCaptionLine()
        toast.show(String(localized: "\(saved.name) on the captions"))
    }

    /// New captions on a video whose captions were never styled start in the default style, whole (its size, place and format
    /// too: there is nothing of the video's own to keep).
    func startsCaptionsInDefaultStyle(_ snapshot: inout EditSnapshot) {
        guard let start = captionStyles.defaultStyle, edit.captions.isEmpty, var current = edit.captionCollection else { return }
        let fresh = CaptionSettings()
        let margins = current.safeMargins
        current.safeMargins = fresh.safeMargins
        current.styleVersion = fresh.styleVersion
        // The format is how the lines are cut, not a look: an edit whose lines were deleted is still unstyled.
        current.format = fresh.format
        guard current == fresh else { return }
        var next: CaptionSettings
        var animation: CaptionAnimation
        switch start {
        case .saved(let id):
            guard let saved = captionStyles.style(id) else { return }
            next = saved.look.settings
            next.savedStyleID = id
            animation = saved.look.animation
        case .builtIn(let name):
            guard let theme = CaptionTheme(rawValue: name) else { return }
            next = CaptionSettings(theme: theme)
            animation = .line
        }
        next.safeMargins = margins
        if let motion = next.motion { animation = motion.nearestAnimation }
        snapshot.captionCollection = next
        snapshot.captionAnimation = animation
    }
}
