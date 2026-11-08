//
//  CaptionsViewModel+LineChoice.swift
//  Cue Studio
//

import Foundation

/// Place and Zoom on the bar of a caption picked on the main timeline (E4 D, canvas 2 §6: the stretch is chosen on the timeline,
/// and what changes is said before the first gesture). The dialog names the line and its time; the choices are the ones of
/// Captions › Select, for that one line. One undo step each.
extension CaptionsViewModel {
    /// Asks where the line `id` goes, or how it zooms.
    func askLineChoice(_ kind: CaptionLineChoice.Kind, for id: UUID?) {
        guard let id, isReady, edit.captions.contains(where: { $0.id == id }) else { return }
        if kind == .place, !canStyleCaptionLines {
            toast.show(String(localized: "Pick a caption style first to place lines on their own"))
            return
        }
        player.pause()
        lineChoice = CaptionLineChoice(lineID: id, kind: kind)
    }

    /// The dialog's title: what it changes, the line alone.
    func lineChoiceTitle(_ choice: CaptionLineChoice) -> String {
        switch choice.kind {
        case .place: String(localized: "Place this line")
        case .zoom: String(localized: "Zoom on this line")
        }
    }

    /// The dialog's message: the line, its time in the video, and what it has now.
    func lineChoiceMessage(_ choice: CaptionLineChoice) -> String {
        guard let line = edit.captions.first(where: { $0.id == choice.lineID }) else { return "" }
        let time = editedSpan(ofCaption: line.id).map { DurationText.editorRange($0.start, $0.end) } ?? ""
        let now: String = switch choice.kind {
        case .place: place(of: [line])?.label ?? String(localized: "Where you dragged it")
        case .zoom: phraseZoom(of: [line])?.label ?? String(localized: "No zoom")
        }
        return String(localized: "\u{201C}\(line.text)\u{201D} · \(time)\nNow: \(now). Only this line changes.")
    }

    /// The line placed at `place`.
    func chooseLinePlace(_ place: CaptionPlace, for choice: CaptionLineChoice) {
        lineChoice = nil
        setPlace(place, ofLines: [choice.lineID])
    }

    /// The line zoomed at `strength`, or not (nil).
    func chooseLineZoom(_ strength: PhraseZoom.Strength?, for choice: CaptionLineChoice) {
        lineChoice = nil
        guard let line = edit.captions.first(where: { $0.id == choice.lineID }) else { return }
        setZoom(strength, onLines: [line])
    }
}
