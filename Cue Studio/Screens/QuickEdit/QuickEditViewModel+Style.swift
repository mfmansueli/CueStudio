//
//  QuickEditViewModel+Style.swift
//  Cue Studio
//

import Foundation

/// Type presets and "My style": the look of texts and captions, applied to one text, every text or
/// the captions. Only the type changes: filters, Adjust and the cover are left alone, and each
/// application is one undo step.
extension QuickEditViewModel {
    /// The text a scope of "This text" means: the one picked, or the one open in its sheet.
    var styledTextID: UUID? { selectedTextID ?? editingTextID }

    /// Sets `preset` on `scope`, as drawn for texts or for captions.
    func applyPreset(_ preset: TypePreset, to scope: TextStyleScope, keepingCustomizations: Bool = false) {
        applyLook(preset.look(for: scope.use), preset: preset, name: preset.label, to: scope, keepingCustomizations: keepingCustomizations)
    }

    /// Sets the saved "My style" on `scope`.
    func applyMyStyle(to scope: TextStyleScope, keepingCustomizations: Bool = false) {
        guard var look = myStyle else { return }
        if scope == .allCaptions {
            // Saved from a title: captions keep a size a line of five words fits in.
            look.sizeScale = min(look.sizeScale, Self.largestCaptionScale)
        }
        applyLook(look, preset: nil, name: String(localized: "My style"), to: scope, keepingCustomizations: keepingCustomizations)
    }

    /// Saves the picked text's look as "My style", for this edit and the next ones.
    func saveMyStyle() {
        guard let id = styledTextID, let text = edit.texts.first(where: { $0.id == id }) else { return }
        let look = TextLook(of: text)
        styles.myStyle = look
        myStyle = look
        toast.show(String(localized: "Saved as My style"))
    }

    /// Which preset `scope` shows now, to mark it: the text's own, the one on every text, or the
    /// captions'. Nil for "My style" or a look set another way.
    func currentPreset(for scope: TextStyleScope) -> TypePreset? {
        switch scope {
        case .selected: styledTextID.flatMap { id in edit.texts.first { $0.id == id } }?.preset
        case .allTexts: edit.textPreset
        case .allCaptions: edit.captionPreset
        case .textsAndCaptions: edit.textPreset == edit.captionPreset ? edit.textPreset : nil
        }
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

    private func applyLook(_ look: TextLook, preset: TypePreset?, name: String, to scope: TextStyleScope, keepingCustomizations: Bool) {
        guard isReady else { return }
        switch scope {
        case .selected:
            guard let id = styledTextID else { return }
            updateText(id) { text in
                look.apply(to: &text)
                text.preset = preset
                text.customized = []
            }
            toast.show(String(localized: "\(name) on this text"))
        case .allTexts:
            change { snapshot in
                snapshot.textLook = look
                snapshot.textPreset = preset
                for index in snapshot.texts.indices {
                    let kept = keepingCustomizations ? snapshot.texts[index].customized : []
                    look.apply(to: &snapshot.texts[index], keeping: kept)
                    snapshot.texts[index].preset = preset
                    if !keepingCustomizations { snapshot.texts[index].customized = [] }
                }
            }
            toast.show(String(localized: "\(name) on every text"))
        case .allCaptions:
            change { snapshot in
                snapshot.captionCollection = nil
                snapshot.captionLook = look
                snapshot.captionPreset = preset
            }
            toast.show(String(localized: "\(name) on the captions"))
        case .textsAndCaptions:
            var captionLook = look
            captionLook.sizeScale = min(look.sizeScale, Self.largestCaptionScale)
            change { snapshot in
                snapshot.textLook = look
                snapshot.textPreset = preset
                for index in snapshot.texts.indices {
                    let kept = keepingCustomizations ? snapshot.texts[index].customized : []
                    look.apply(to: &snapshot.texts[index], keeping: kept)
                    snapshot.texts[index].preset = preset
                    if !keepingCustomizations { snapshot.texts[index].customized = [] }
                }
                snapshot.captionCollection = nil
                snapshot.captionLook = captionLook
                snapshot.captionPreset = preset
            }
            toast.show(String(localized: "\(name) on all text + captions"))
        }
    }
}
