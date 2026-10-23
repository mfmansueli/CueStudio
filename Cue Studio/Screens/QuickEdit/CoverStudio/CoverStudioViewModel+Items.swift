//
//  CoverStudioViewModel+Items.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The Graphics step: arrows, circles, tags and the handle as things of their own, picked, dragged, resized and turned on the
/// canvas (with one finger on the corner handle or two anywhere), recolored, written in, copied, put in front or behind, and
/// deleted. Each change is one undo step; a gesture is one.
extension CoverStudioViewModel {
    var selectedItem: CoverItem? {
        selection?.itemID.flatMap { composition.item($0) }
    }

    /// Adds a graphic in the middle, a little apart from the last one added, and picks it.
    func addItem(_ kind: CoverItemKind) {
        let offset = Double(composition.items.count % 4) * 0.05
        var item = CoverItem(kind: kind, center: OverlayPoint(x: 0.5 + offset, y: 0.5 + offset))
        switch kind {
        case .tag: item.text = String(localized: "NEW", comment: "Default words of a tag on a cover")
        case .handle: item.text = handle.isEmpty ? String(localized: "yourname", comment: "Placeholder handle on a cover") : handle
        case .arrow, .circle: break
        }
        changeComposition { $0.items.append(item) }
        selection = .item(item.id)
        step = .elements
    }

    func updateItem(_ id: UUID, key: String? = nil, _ update: (inout CoverItem) -> Void) {
        changeComposition(key: key) { composition in
            guard let index = composition.items.firstIndex(where: { $0.id == id }) else { return }
            update(&composition.items[index])
            composition.items[index].isFromTemplate = false
            composition.items[index] = composition.items[index].clamped
        }
    }

    /// A finger moved the graphic from where it was when the gesture began.
    func moveItem(_ id: UUID, from base: OverlayPoint, by translation: CGSize, in size: CGSize) {
        let proposed = OverlayPoint(
            x: base.x + Double(translation.width / max(1, size.width)), y: base.y + Double(translation.height / max(1, size.height))
        )
        let snapped = CoverSnapping.snapped(proposed)
        showGuides(vertical: snapped.vertical, horizontal: snapped.horizontal)
        updateItem(id) { $0.center = snapped.point }
    }

    /// Resized by `factor` and turned by `angle` (radians) from how it was when the gesture began. Turns stick to upright
    /// within 4°.
    func transformItem(_ id: UUID, from base: (scale: Double, rotation: Double), scale factor: Double, rotation angle: Double) {
        var rotation = base.rotation + angle
        let quarter = Double.pi / 2
        let nearest = (rotation / quarter).rounded() * quarter
        if abs(rotation - nearest) < 4 * .pi / 180 { rotation = nearest }
        updateItem(id) { item in
            item.scale = base.scale * factor
            item.rotation = rotation
        }
    }

    func duplicateItem(_ id: UUID) {
        guard var copy = composition.item(id) else { return }
        copy.id = UUID()
        copy.isFromTemplate = false
        copy.center = OverlayPoint(x: copy.center.x + 0.05, y: copy.center.y + 0.05).clamped
        changeComposition { composition in
            let index = composition.items.firstIndex { $0.id == id }.map { $0 + 1 } ?? composition.items.count
            composition.items.insert(copy, at: index)
        }
        selection = .item(copy.id)
    }

    func deleteItem(_ id: UUID) {
        changeComposition { $0.items.removeAll { $0.id == id } }
        if selection == .item(id) { selection = nil }
        Haptics.delete()
    }

    /// One place in front (`forward`) or behind.
    func restackItem(_ id: UUID, forward: Bool) {
        changeComposition { composition in
            guard let index = composition.items.firstIndex(where: { $0.id == id }) else { return }
            let target = forward ? index + 1 : index - 1
            guard composition.items.indices.contains(target) else { return }
            composition.items.swapAt(index, target)
        }
    }

    func canRestack(_ id: UUID, forward: Bool) -> Bool {
        guard let index = composition.items.firstIndex(where: { $0.id == id }) else { return false }
        return forward ? index < composition.items.count - 1 : index > 0
    }
}
