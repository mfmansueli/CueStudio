//
//  CaptionsViewModel+Places.swift
//  Cue Studio
//

import Foundation

/// A stretch of caption lines in its own place (E4 D, owner 07/11/2026): Captions › Select › Place puts the picked lines at the
/// top, the middle or the bottom, apart from every other caption, or back with them. On the preview, a line in its own place
/// drags its stretch (the lines that share the place) and a picked line drags the picked ones; any other drags every caption.
/// Its own place beats the split screen's seam, and its translation goes with it. One undo step each.
extension CaptionsViewModel {
    /// What a drag of the caption `id` on the preview moves: these lines in their own place, or every caption (nil).
    func captionDragLines(_ id: UUID) -> Set<UUID>? {
        guard canStyleCaptionLines else { return nil }
        if let picks = captionPicks, picks.contains(id) { return picks }
        guard let own = ownPlace(of: id) else { return nil }
        return Set(edit.captions.filter { $0.lineStyle?.y == own }.map(\.id))
    }

    /// What the drag's label says it moves.
    func captionDragScope(_ id: UUID) -> String {
        guard let lines = captionDragLines(id) else { return String(localized: "All captions") }
        if captionPicks?.contains(id) == true { return String(localized: "Selected lines") }
        return lines.count == 1 ? String(localized: "This line") : String(localized: "This stretch")
    }

    /// The height of the caption `id` on the frame (unit, from the top): its own place, or where every caption is.
    func captionY(of id: UUID) -> Double {
        ownPlace(of: id) ?? captionY
    }

    /// The caption `id` dropped at `y` on the preview: its stretch (or the picked lines) there, sticking to top, middle and
    /// bottom; else every caption, as before.
    func moveCaption(_ id: UUID, toY y: Double) {
        guard let lines = captionDragLines(id) else {
            moveCaptions(toY: y)
            return
        }
        let placed = Self.snappedCaption(y).y
        placeLines(lines, at: placed)
    }

    /// The place the picked lines share; nil when they differ or one is somewhere a drag left it.
    var pickedCaptionPlace: CaptionPlace? {
        let places = Set(pickedCaptionLines.map { $0.lineStyle?.y })
        guard places.count == 1, let place = places.first else { return nil }
        guard let y = place else { return .withAll }
        return CaptionPosition.allCases.first { abs($0.verticalFraction - y) < 0.000_1 }.map(CaptionPlace.own)
    }

    /// The picked lines with every caption, or in their own place.
    func setPickedCaptionsPlace(_ place: CaptionPlace) {
        guard let picks = captionPicks, !picks.isEmpty else { return }
        switch place {
        case .withAll: placeLines(picks, at: nil)
        case .own(let position): placeLines(picks, at: position.verticalFraction)
        }
    }

    /// How many lines have their own place.
    var captionsInOwnPlace: Int {
        edit.captions.count { $0.lineStyle?.y != nil }
    }

    /// Every line back with the others, one undo step.
    func placeEveryCaptionWithAll() {
        placeLines(Set(edit.captions.map(\.id)), at: nil)
    }

    // MARK: - Private

    private func ownPlace(of id: UUID) -> Double? {
        edit.captions.first { $0.id == id }?.lineStyle?.y
    }

    private func placeLines(_ ids: Set<UUID>, at y: Double?) {
        guard canStyleCaptionLines, isReady else { return }
        let target = y.map { min(max($0, 0.1), 0.9) }
        guard edit.captions.contains(where: { ids.contains($0.id) && $0.lineStyle?.y != target }) else { return }
        change { snapshot in
            guard var lines = snapshot.captions else { return }
            for index in lines.indices where ids.contains(lines[index].id) {
                var style = lines[index].lineStyle ?? CaptionLineStyle()
                style.y = target
                lines[index].lineStyle = style.isPlain ? nil : style
            }
            snapshot.captions = lines
        }
        Haptics.selection()
        if let first = edit.captions.first(where: { ids.contains($0.id) }), let span = editedSpan(ofCaption: first.id),
           !span.contains(player.currentTime) {
            player.pause()
            player.seek(to: span.start + 0.05)
        }
    }
}
