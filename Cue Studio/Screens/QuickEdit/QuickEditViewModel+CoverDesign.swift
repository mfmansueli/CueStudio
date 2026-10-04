//
//  QuickEditViewModel+CoverDesign.swift
//  Cue Studio
//

import Foundation

/// Cover's v26 design: the layout, the typeface, the highlighted word, what is done to the picture
/// and the elements on top, plus "My cover style". Each change is one undo step, and typing the
/// title in a row is one (the cover is drawn again a moment after the last change).
extension QuickEditViewModel {
    /// The cover's design (a cover without one is drawn the old way: its design starts here).
    var coverDesign: CoverDesign {
        edit.cover?.design ?? newCoverDesign
    }

    /// A new cover starts in "My cover style" when there is one.
    var newCoverDesign: CoverDesign {
        var design = CoverDesign()
        if let myCoverLook { design.apply(myCoverLook) }
        design.handle = creatorHandle
        return design
    }

    func setCoverLayout(_ layout: CoverLayout) {
        updateCoverDesign { design in
            design.layout = layout
            // The highlighted word stays inside the words the layout draws.
            if layout == .hook || layout == .question { design.highlightIndex = min(design.highlightIndex, 1) }
        }
    }

    func setCoverFont(_ font: CoverFont) {
        updateCoverDesign { $0.font = font }
    }

    func setCoverEffect(_ effect: CoverEffect) {
        updateCoverDesign { $0.effect = effect }
    }

    func toggleCoverElement(_ element: CoverElement) {
        let handle = creatorHandle
        updateCoverDesign { design in
            if design.elements.contains(element) {
                design.elements.remove(element)
            } else {
                design.elements.insert(element)
            }
            design.handle = handle
        }
    }

    func setCoverHighlight(_ index: Int) {
        updateCoverDesign { $0.highlightIndex = max(0, index) }
    }

    /// "✦ From your script": the words become this title, with the second word highlighted.
    func useCoverSuggestion(_ title: String) {
        guard isReady else { return }
        ensureCover()
        change { snapshot in
            snapshot.cover?.title = title
            let count = title.split(whereSeparator: \.isWhitespace).count
            snapshot.cover?.design?.highlightIndex = min(1, max(0, count - 1))
        }
    }

    /// Titles Cue can offer from the take's own words: a text on the video, the script's title and
    /// its first sentence, short enough for a cover.
    var coverSuggestions: [String] {
        let sentence = captionScript.flatMap { script in
            script.text.split(whereSeparator: { ".!?\n".contains($0) }).first.map { $0.trimmingCharacters(in: .whitespaces) }
        }
        var seen = Set<String>()
        return [edit.texts.first?.text, take.scriptTitle, sentence]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 42 && seen.insert($0.lowercased()).inserted }
            .prefix(3)
            .map { $0 }
    }

    /// The title's words as the layout draws them, for the highlight chips.
    var coverWords: [String] {
        coverDesign.words(of: edit.cover?.title ?? "").words
    }

    /// "Save as my style": layout, typeface, effect and series tag, for new covers.
    func saveMyCoverStyle() {
        let look = coverDesign.look
        styles.myCoverLook = look
        myCoverLook = look
        toast.show(String(localized: "Saved · Used for new covers"))
    }

    /// "Apply my cover style": the saved look on this cover (the words stay).
    func applyMyCoverStyle() {
        guard let look = myCoverLook else { return }
        updateCoverDesign { $0.apply(look) }
    }

    // MARK: - Changes

    /// Makes a cover from the playhead's frame when there is none, so a tile always has something
    /// to change.
    private func ensureCover() {
        guard edit.cover == nil, isReady else { return }
        let time = edit.timeline.sourceTime(forEdited: player.currentTime)
        change { snapshot in
            var cover = VideoCover(source: .frame(time), style: snapshot.creatorStyle ?? .bold)
            cover.design = newCoverDesign
            snapshot.cover = cover
        }
    }

    private func updateCoverDesign(_ transform: @escaping (inout CoverDesign) -> Void) {
        guard isReady else { return }
        ensureCover()
        let fallback = coverDesign
        change { snapshot in
            var design = snapshot.cover?.design ?? fallback
            transform(&design)
            snapshot.cover?.design = design
        }
    }
}
