//
//  CoverStudioViewModel+Design.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The Template, Title and Finish steps: a template (keeping what the creator made), the title's words and how they're set,
/// moving the title on the canvas, the effect, and "My cover style".
extension CoverStudioViewModel {
    // MARK: - Template

    func applyTemplate(_ template: CoverTemplate) {
        Haptics.selection()
        let title = cover.title
        changeComposition { composition in
            composition = composition.applying(template, title: title, handle: handle)
        }
        if template == .beforeAfter, step == .template { editsSecondPicture = false }
    }

    // MARK: - Title

    /// Typing the title: one undo step per pause in typing; the key word is highlighted when nothing is yet.
    func setTitle(_ title: String) {
        let words = CoverWords.words(in: title).count
        change(key: "cover.title") { cover in
            let hadNoWords = CoverWords.words(in: cover.title).isEmpty
            cover.title = title
            guard var style = cover.composition?.title else { return }
            style.highlights = style.highlights.filter { $0 < words }
            if hadNoWords, style.highlights.isEmpty, cover.composition?.template != .list, let key = CoverWords.keyWord(in: title) {
                style.highlights = [key]
            }
            cover.composition?.title = style
        }
    }

    /// The title's words, for the highlight chips.
    var titleWords: [String] {
        CoverWords.words(in: cover.title)
    }

    func toggleHighlight(_ index: Int) {
        updateTitle { style in
            if style.highlights.contains(index) { style.highlights.remove(index) } else { style.highlights.insert(index) }
        }
    }

    func updateTitle(key: String? = nil, _ update: (inout CoverTitleStyle) -> Void) {
        changeComposition(key: key) { composition in
            update(&composition.title)
            composition.title = composition.title.clamped
        }
    }

    /// A finger moved the title (its block's center, from where it was when the gesture began) on a canvas of `size`.
    func moveTitle(from base: OverlayPoint, by translation: CGSize, in size: CGSize) {
        let proposed = OverlayPoint(
            x: base.x + Double(translation.width / max(1, size.width)), y: base.y + Double(translation.height / max(1, size.height))
        )
        let snapped = CoverSnapping.snapped(proposed)
        showGuides(vertical: snapped.vertical, horizontal: snapped.horizontal)
        updateTitle { $0.center = snapped.point }
    }

    /// Two fingers on the title: its size by `factor` from what it was.
    func resizeTitle(from base: Double, by factor: Double) {
        updateTitle { $0.size = base * factor }
    }

    // MARK: - Finish

    func setEffect(_ effect: CoverEffect) {
        Haptics.selection()
        changeComposition { $0.effect = effect }
    }

    func setEffectAmount(_ amount: Double) {
        changeComposition { $0.effectAmount = min(max(amount, 0), 1) }
    }

    /// "Save as my style": this cover's look (never its words or picture) for the next covers.
    func saveMyStyle() {
        setMyStyle(composition.style)
        toast.show(String(localized: "Saved · Used for new covers"))
    }

    /// "Apply my style": the saved look on this cover; its words, picture and graphics stay.
    func applyMyStyle() {
        guard let myStyle else { return }
        changeComposition { composition in
            composition = myStyle.apply(to: composition)
        }
    }
}
