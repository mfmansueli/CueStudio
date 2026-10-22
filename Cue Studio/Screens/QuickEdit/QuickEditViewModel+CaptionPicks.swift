//
//  QuickEditViewModel+CaptionPicks.swift
//  Cue Studio
//

import Foundation

/// Captions › Select: several lines picked at once, then styled, moved or deleted together, as CapCut's caption batch edit
/// does. Each action is one undo step. A line's style (`CaptionLineStyle`) is the whole line lit in the highlight color and
/// bigger type; moving keeps every picked line inside its clip and off the lines that weren't picked.
extension QuickEditViewModel {
    /// How far one Earlier or Later moves the picked lines.
    static let captionGroupStep: TimeInterval = 0.1

    var isPickingCaptions: Bool { captionPicks != nil }

    /// How tall the open panel is: Captions grows to the styling panels' height while lines are picked, so the list, its
    /// header and its actions all have room.
    var openPanelSize: EditorPanelSize? {
        guard let panel else { return nil }
        return panel == .captions && isPickingCaptions ? .full : panel.size
    }

    /// Starts picking lines, with `first` picked (a line held in the list), or none.
    func startPickingCaptions(with first: UUID? = nil) {
        guard isReady, !edit.captions.isEmpty else { return }
        if selection?.captionID != nil { selection = nil }
        captionPicks = first.map { [$0] } ?? []
        Haptics.selection()
    }

    func stopPickingCaptions() {
        captionPicks = nil
    }

    /// A line tapped while picking: in or out.
    func toggleCaptionPick(_ id: UUID) {
        guard var picks = captionPicks else { return }
        if picks.contains(id) { picks.remove(id) } else { picks.insert(id) }
        captionPicks = picks
        Haptics.selection()
    }

    /// Every line that plays is picked (or none, when they all were).
    var picksEveryCaption: Bool {
        let all = Set(captionLinesInPlayOrder.map(\.id))
        return !all.isEmpty && (captionPicks.map { all.isSubset(of: $0) } ?? false)
    }

    func togglePickAllCaptions() {
        guard captionPicks != nil else { return }
        captionPicks = picksEveryCaption ? [] : Set(captionLinesInPlayOrder.map(\.id))
    }

    /// The picked lines that still exist, in play order.
    var pickedCaptionLines: [CaptionCue] {
        guard let picks = captionPicks else { return [] }
        return captionLinesInPlayOrder.filter { picks.contains($0.id) }
    }

    // MARK: - Style

    /// Line styles draw with the captions' collection look (every edit since caption presets); older captions keep one look.
    var canStyleCaptionLines: Bool { edit.captionCollection != nil }

    /// Whether every picked line is emphasized (the Emphasis switch is on).
    var pickedCaptionsAreEmphasized: Bool {
        let lines = pickedCaptionLines
        return !lines.isEmpty && lines.allSatisfy { $0.lineStyle?.isEmphasized == true }
    }

    /// The size the picked lines share; nil when they differ.
    var pickedCaptionSize: CaptionLineStyle.Size? {
        let sizes = Set(pickedCaptionLines.map { $0.lineStyle?.size ?? .regular })
        return sizes.count == 1 ? sizes.first : nil
    }

    /// Emphasis on (or off) for every picked line, one undo step.
    func setPickedCaptionsEmphasized(_ emphasized: Bool) {
        restylePickedCaptions { $0.isEmphasized = emphasized }
        if !emphasized || edit.showsCaptions { previewFirstPickedLine() }
    }

    func setPickedCaptionSize(_ size: CaptionLineStyle.Size) {
        restylePickedCaptions { $0.size = size }
        previewFirstPickedLine()
    }

    private func restylePickedCaptions(_ update: (inout CaptionLineStyle) -> Void) {
        guard canStyleCaptionLines, let picks = captionPicks, !picks.isEmpty else { return }
        change { snapshot in
            guard var lines = snapshot.captions else { return }
            for index in lines.indices where picks.contains(lines[index].id) {
                var style = lines[index].lineStyle ?? CaptionLineStyle()
                update(&style)
                lines[index].lineStyle = style.isPlain ? nil : style
            }
            snapshot.captions = lines
        }
    }

    /// Shows the first picked line, so the change is seen.
    private func previewFirstPickedLine() {
        guard let first = pickedCaptionLines.first, let span = editedSpan(ofCaption: first.id) else { return }
        player.pause()
        player.seek(to: span.start + 0.05)
    }

    // MARK: - Moving

    /// Earlier (−) or Later (+): every picked line moves by the same time of the edit, as far as the one with the least room
    /// can go (inside its clip, never onto a line that wasn't picked). Quick taps are one undo step. False when none can move.
    @discardableResult
    func movePickedCaptions(by seconds: TimeInterval) -> Bool {
        guard isReady, let picks = captionPicks, !picks.isEmpty else { return false }
        let timeline = edit.timeline
        let shown = editedCaptionLines
        // Each picked line where it first plays, with the room it has on both sides (edited seconds).
        // Each line with its clip and where in the clip it starts (edited seconds).
        var moves: [(id: UUID, segment: EditSegment, offset: TimeInterval)] = []
        var earliest = -TimeInterval.greatestFiniteMagnitude
        var latest = TimeInterval.greatestFiniteMagnitude
        for (position, line) in shown.enumerated() where picks.contains(line.id) && !moves.contains(where: { $0.id == line.id }) {
            let piece = timeline.segmentIndex(atEdited: line.start + 0.000_1)
            let pieceStart = timeline.editedStart(ofSegmentAt: piece)
            let segment = timeline.segments[piece]
            let before = shown[..<position].last { !picks.contains($0.id) }?.end ?? 0
            let after = shown[(position + 1)...].first { !picks.contains($0.id) }?.start ?? edit.editedDuration
            earliest = max(earliest, max(before, pieceStart) - line.start)
            latest = min(latest, min(after, pieceStart + segment.duration) - line.end)
            moves.append((line.id, segment, line.start - pieceStart))
        }
        let shift = min(max(seconds, min(0, earliest)), max(0, latest))
        guard !moves.isEmpty, abs(shift) >= 0.005 else {
            toast.show(String(localized: "The lines can’t move further"))
            return false
        }
        let segments = Dictionary(moves.map { ($0.id, (segment: $0.segment, offset: $0.offset)) }) { first, _ in first }
        change(key: "captionGroupMove") { snapshot in
            guard var lines = snapshot.captions else { return }
            for index in lines.indices {
                guard let piece = segments[lines[index].id], piece.segment.sourceID == lines[index].sourceID else { continue }
                // Edited seconds become seconds of the line's recording at its clip's speed (along its curve, where it is).
                let source = piece.segment.sourceOffset(forEdited: piece.offset + shift) - piece.segment.sourceOffset(forEdited: piece.offset)
                var moved = lines[index]
                moved.start += source
                moved.end += source
                moved.words = moved.words.map { word in
                    CaptionWord(text: word.text, start: word.start + source, end: word.end + source, isEstimated: word.isEstimated)
                }
                moved.isRevised = true
                lines[index] = moved
            }
            snapshot.captions = lines.sorted { $0.start < $1.start }
        }
        if let first = pickedCaptionLines.first, let span = editedSpan(ofCaption: first.id) {
            player.pause()
            player.seek(to: span.start + 0.01)
        }
        return true
    }

    // MARK: - Deleting

    /// Every picked line goes, one undo step (Undo in the toast brings them back); picking ends.
    func deletePickedCaptions() {
        guard isReady, let picks = captionPicks, !picks.isEmpty else { return }
        let count = edit.captions.filter { picks.contains($0.id) }.count
        change { snapshot in snapshot.captions?.removeAll { picks.contains($0.id) } }
        captionPicks = nil
        Haptics.delete()
        toast.show(
            String(localized: "\(count) lines deleted"),
            action: ToastAction(title: String(localized: "Undo")) { [weak self] in self?.undo() }
        )
    }
}
