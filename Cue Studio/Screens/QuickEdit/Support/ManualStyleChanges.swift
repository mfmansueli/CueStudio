//
//  ManualStyleChanges.swift
//  Cue Studio
//

import Foundation

/// What the creator styled by hand that a kit or a template would otherwise put its own look over (owner, 08/11/2026, H): the
/// titles with a look field changed by hand (`TextOverlay.customized`) that the style sets, and the caption lines with a look
/// of their own (`CaptionLineStyle`: Emphasize line, size). By default both stay; the sheet offers to replace them, unchecked,
/// with these counts. Where a text sits (`position`) always stays, as every caption line's timing and words do.
struct ManualStyleChanges: Equatable {
    /// Titles (texts, not graphics) the style would change something the creator set by hand on.
    let titles: Int
    /// Caption lines with a look of their own.
    let captionLines: Int

    /// `snapshot`'s hand-made changes in the fields a style sets (`replaced`); captions only when `touchesCaptions`.
    init(in snapshot: EditSnapshot, replacing replaced: Set<TextLookField>, touchesCaptions: Bool) {
        titles = snapshot.texts.filter { $0.graphic == nil && !$0.customized.intersection(replaced).subtracting([.position]).isEmpty }.count
        captionLines = touchesCaptions ? (snapshot.captions ?? []).filter { !($0.lineStyle?.isPlain ?? true) }.count : 0
    }

    init(titles: Int, captionLines: Int) {
        self.titles = titles
        self.captionLines = captionLines
    }

    var isEmpty: Bool { titles == 0 && captionLines == 0 }

    /// Every look field but the place: what a text style sets.
    static let wholeLook = Set(TextLookField.allCases).subtracting([.position])
    /// What a font sets.
    static let font: Set<TextLookField> = [.font, .weight]
}

/// Which of the creator's hand-made changes a kit or a template replaces too (both unchecked: none).
struct ReplacedManualChanges: Equatable {
    var titles = false
    var captionLines = false
}
