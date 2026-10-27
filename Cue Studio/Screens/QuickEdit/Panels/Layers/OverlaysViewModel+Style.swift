//
//  OverlaysViewModel+Style.swift
//  Cue Studio
//

import Foundation

/// Type presets and "My style": the look of texts, applied to one text or every text (and, from older
/// flows, to the captions' type look). Only the type changes: filters, Adjust and the cover are left
/// alone, and each application is one undo step. A text keeps its words, its place, its turn, the size
/// the creator gave it by hand, its timing, its clip and its keyframes and Motion.
extension OverlaysViewModel {
    /// The text a scope of "This text" means: the one picked, or the one open in its sheet.
    var styledTextID: UUID? { selectedTextID ?? editingTextID }

    /// Sets `preset` on `scope`, as drawn for texts or for captions.
    func applyPreset(_ preset: TypePreset, to scope: TextStyleScope, keepingCustomizations: Bool = false) {
        applyLook(preset.look(for: scope.use), preset: preset, name: preset.label, to: scope, keepingCustomizations: keepingCustomizations)
    }

    /// Sets a saved text style on `scope`.
    func applySavedTextStyle(_ id: UUID, to scope: TextStyleScope, keepingCustomizations: Bool = false) {
        guard let saved = textStyles.style(id) else { return }
        var look = saved.look
        if scope == .allCaptions {
            // Saved from a title: captions keep a size a line of five words fits in.
            look.sizeScale = min(look.sizeScale, Self.largestCaptionScale)
        }
        applyLook(look, preset: nil, name: saved.name, to: scope, keepingCustomizations: keepingCustomizations)
    }

    /// Changes one part of a text's look by hand: it is remembered, so "Keep my changes" keeps it
    /// when a preset goes on every text.
    func customizeText(_ id: UUID, _ field: TextLookField, key: String? = nil, _ update: (inout TextOverlay) -> Void) {
        updateText(id, key: key) { text in
            let before = text
            update(&text)
            if text != before { text.customized.insert(field) }
        }
    }

    // MARK: - Private

    /// Captions never grow past this times their base size, so a line of five words fits.
    private static var largestCaptionScale: Double { 1.3 }

    /// What the creator did by hand to place a text, which a style never undoes.
    private static var placing: Set<TextLookField> { [.position, .size] }

    /// "Gold on this text"; when a style that moves took a text's Motion off (`wearing`), it says so with Undo: nothing the
    /// creator chose goes away without a word.
    private func sayApplied(_ name: String, on texts: [TextOverlay], every: Bool, effect: TextEffect?) {
        guard effect?.isAnimated == true, texts.contains(where: { $0.animation != nil }) else {
            toast.show(every ? String(localized: "\(name) on every text") : String(localized: "\(name) on this text"))
            return
        }
        sayUndoable(every
            ? String(localized: "\(name) on every text · Motions removed, the style moves them")
            : String(localized: "\(name) on this text · Motion removed, the style moves it"))
    }

    /// A look whose effect moves is worn as its card shows: a Motion would play instead of the effect's way in, so it goes.
    private static func wearing(_ look: TextLook, _ text: inout TextOverlay) {
        if look.effect?.isAnimated == true, text.effect?.isAnimated == true { text.animation = nil }
    }

    private func applyLook(_ look: TextLook, preset: TypePreset?, name: String, to scope: TextStyleScope, keepingCustomizations: Bool) {
        guard isReady else { return }
        switch scope {
        case .selected:
            guard let id = styledTextID, let before = edit.texts.first(where: { $0.id == id }) else { return }
            updateText(id) { text in
                // A style changes the look, never the place: the text stays where it is, as big as the creator made it.
                let placed = text.customized.intersection(Self.placing)
                look.apply(to: &text, keeping: placed.union([.position]))
                Self.wearing(look, &text)
                text.preset = preset
                text.customized = placed
            }
            sayApplied(name, on: [before], every: false, effect: look.effect)
        case .allTexts:
            let before = edit.texts.filter { $0.graphic == nil }
            change { snapshot in
                snapshot.textLook = look
                snapshot.textPreset = preset
                // Graphics keep their own look: a type preset is for words.
                for index in snapshot.texts.indices where snapshot.texts[index].graphic == nil {
                    let placed = snapshot.texts[index].customized.intersection(Self.placing)
                    let kept = keepingCustomizations ? snapshot.texts[index].customized : placed
                    look.apply(to: &snapshot.texts[index], keeping: kept.union([.position]))
                    Self.wearing(look, &snapshot.texts[index])
                    snapshot.texts[index].preset = preset
                    if !keepingCustomizations { snapshot.texts[index].customized = placed }
                }
            }
            sayApplied(name, on: before, every: true, effect: look.effect)
        case .allCaptions:
            change { snapshot in
                snapshot.captionCollection = nil
                snapshot.captionLook = look
                snapshot.captionPreset = preset
            }
            toast.show(String(localized: "\(name) on the captions"))
        }
    }
}
