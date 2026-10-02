//
//  QuickEditViewModel+CaptionPanels.swift
//  Cue Studio
//

import Foundation

/// The Captions, Auto captions and Caption style panels: the lines with their times (tap one to
/// go there; the one picked opens to be corrected, its start and end nudged in tenths without
/// running into its neighbors), a line added in a free gap at the playhead, the language spoken,
/// a translation picked inline, and the look of every line at once (the collection's presets, how
/// lines appear, where they sit and how big).
extension QuickEditViewModel {
    /// Sizes Caption style offers, in points on the design's frame.
    static let captionSizeRange: ClosedRange<Double> = 12...28
    /// The size every collection look is drawn at when its scale is 1.
    static let captionBaseSize = TextLook.captionBaseSize
    /// Shortest free gap a new line fits in.
    static let minimumCaptionGap: TimeInterval = 0.3
    /// How long a line added by hand lasts when there is room.
    static let addedCaptionLength: TimeInterval = 1.6

    // MARK: - Lines

    /// The lines in the order they play: each instance in the edit (a copied section shows a line
    /// again), with the line it comes from.
    var captionListLines: [(line: CaptionCue, cueID: UUID)] {
        edit.editedCaptionInstances.sorted { $0.line.start < $1.line.start }
    }

    /// The line playing under the playhead (the line it comes from).
    var activeCaptionCueID: UUID? {
        let time = player.currentTime
        return edit.editedCaptionInstances.first { $0.line.start <= time && time < $0.line.end }?.cueID
    }

    /// A line tapped in the list: the playhead goes to its start and the timeline picks it too.
    func pickCaptionLine(_ cueID: UUID, at start: TimeInterval) {
        guard isReady else { return }
        previewTask?.cancel()
        player.pause()
        player.seek(to: start + 0.01)
        if selection != .caption(cueID) { Haptics.selection() }
        selection = .caption(cueID)
    }

    /// Plays the line once and comes back to its start.
    func playCaptionLine(start: TimeInterval, end: TimeInterval) {
        guard isReady, end > start else { return }
        previewPart(start...end, back: start + 0.01)
    }

    /// Start or End −/+: the line's edge moves by a tenth (never over a neighbor) and the playhead
    /// goes there, to see it. Quick taps are one undo step.
    func nudgeCaptionLine(_ id: UUID, edge: TrimHandle, by seconds: TimeInterval) {
        nudgeCaption(id, edge: edge, by: seconds)
        guard let span = editedSpan(ofCaption: id) else { return }
        player.pause()
        player.seek(to: edge == .start ? span.start + 0.01 : max(span.start, span.end - 0.3))
    }

    /// "Add a line at the playhead": a new line in the free gap there, picked to be written. Not
    /// over another line, and only where 0.3 s or more is free.
    func addCaptionAtPlayhead() {
        guard isReady else { return }
        let time = player.currentTime
        let lines = editedCaptionLines
        if lines.contains(where: { $0.start <= time && time < $0.end }) {
            toast.show(String(localized: "There is a line here — move to a gap"))
            return
        }
        let next = lines.first { $0.start > time }?.start ?? edit.editedDuration
        let end = min(time + Self.addedCaptionLength, next)
        guard end - time >= Self.minimumCaptionGap else {
            toast.show(String(localized: "Not enough room here"))
            return
        }
        player.pause()
        // On the recording that plays there (another take's, in a montage).
        let pinned = edit.timeline.anchoredSpan(forEdited: TimeSpan(start: time, end: end))
        var cue = CaptionCue(text: String(localized: "New line"), start: pinned.span.start, end: pinned.span.end, origin: .manual)
        cue.sourceID = pinned.anchor.sourceID
        change { snapshot in
            var lines = snapshot.captions ?? []
            lines.append(cue)
            snapshot.captions = lines.sorted { $0.start < $1.start }
        }
        edit.showsCaptions = true
        selection = .caption(cue.id)
        focusesCaptionField = true
        player.seek(to: time + 0.01)
    }

    /// Captions › the switch: shows or hides every line. Showing them when there are none makes
    /// them (Auto captions).
    func toggleCaptions() {
        if edit.captions.isEmpty {
            panel = .autoCaptions
            return
        }
        edit.showsCaptions.toggle()
    }

    // MARK: - Language and translation

    /// The language chip: "Auto" or the language picked.
    var captionLanguageLabel: String {
        edit.captionLanguage?.nativeName ?? String(localized: "Auto")
    }

    /// The Translate chip: "Translate", or the language the captions show in.
    var captionTranslationLabel: String {
        edit.captionDisplay.language?.nativeName ?? String(localized: "Translate")
    }

    /// A language picked under Translate: shown when already translated, else translated on the
    /// iPhone and then shown. Nil goes back to the original.
    func pickCaptionTranslation(_ language: CueLanguage?) async {
        guard let language else {
            if edit.captionDisplay != .original { setCaptionDisplay(.original) }
            return
        }
        if translation(language) != nil {
            setCaptionDisplay(.translation(language))
            toast.show(String(localized: "Captions in \(language.localizedName)"))
            return
        }
        await translateCaptions(to: language, shows: true)
    }

    // MARK: - Auto captions

    /// "Write them myself": a take no model can hear is captioned by hand, from the playhead.
    func writeCaptionsByHand() {
        panel = .captions
        addCaptionAtPlayhead()
    }

    // MARK: - Caption style

    /// The collection's look the presets show as picked; nil while captions draw with a text
    /// look (set from Text style's "+ Captions") or the old caption style.
    var captionTheme: CaptionTheme? { edit.captionCollection?.theme }

    /// A collection preset on every line (one undo step). A preset is a complete recipe, so it
    /// brings its own reveal with it (Educational lights the word said, Interview only fades the
    /// line); Reveal can change it after.
    func pickCaptionTheme(_ theme: CaptionTheme) {
        guard captionTheme != theme else { return }
        setCaptionTheme(theme)
        applyCaptionReveal(CaptionStyleSpec.spec(for: theme, version: CaptionStyleSpec.currentVersion).animation)
        previewCurrentCaptionLine()
    }

    /// How lines appear, as it plays now.
    var captionReveal: CaptionAnimation {
        guard let settings = edit.captionCollection else { return edit.captionAnimation }
        return CaptionCollectionRenderer.effectiveAnimation(settings: settings, animation: edit.captionAnimation)
    }

    /// Reveal: Line, Fade, Words, Highlight or Box on every line, then the current line plays to
    /// show it.
    func pickCaptionReveal(_ reveal: CaptionAnimation) {
        guard isReady else { return }
        if edit.captionCollection != nil {
            applyCaptionReveal(reveal)
        } else {
            setCaptionAnimation(reveal)
        }
        previewCurrentCaptionLine()
    }

    private func applyCaptionReveal(_ reveal: CaptionAnimation) {
        guard edit.captionCollection != nil else { return }
        change { snapshot in
            snapshot.captionAnimation = reveal
            snapshot.captionCollection?.followsWords = reveal.followsWords
        }
    }

    /// Plays the line under the playhead (or the first one) once.
    func previewCurrentCaptionLine() {
        let lines = editedCaptionLines
        let time = player.currentTime
        guard let line = lines.first(where: { $0.start <= time && time < $0.end }) ?? lines.first else { return }
        previewPart(line.start...line.end, back: line.start + 0.05)
    }

    /// Top, Middle or Bottom: the one nearest to where the captions sit.
    var captionPositionStop: CaptionPosition {
        let y = captionY
        if y < 0.33 { return .top }
        if y < 0.63 { return .middle }
        return .bottom
    }

    func setCaptionPositionStop(_ position: CaptionPosition) {
        let index = CaptionPosition.allCases.firstIndex(of: position) ?? 2
        moveCaptions(toY: Self.captionStops[index])
    }

    /// The captions' size in points on the design's frame (12 to 28).
    var captionPointSize: Double {
        let scale = edit.captionCollection?.clampedScale ?? edit.captionLook?.sizeScale ?? 1
        return (Self.captionBaseSize * scale).rounded()
    }

    /// A drag on Size is one undo step.
    func setCaptionPointSize(_ size: Double) {
        let clamped = min(max(size.rounded(), Self.captionSizeRange.lowerBound), Self.captionSizeRange.upperBound)
        let scale = clamped / Self.captionBaseSize
        if edit.captionCollection != nil {
            change(key: "captionSize") { $0.captionCollection?.sizeScale = scale }
        } else {
            change(key: "captionSize") { snapshot in
                var look = snapshot.captionLook ?? TypePreset.cue.look(for: .caption)
                look.sizeScale = scale
                snapshot.captionLook = look
            }
        }
    }

    /// The highlight color of the collection's look (Font › Color).
    var captionAccent: CaptionAccent? { edit.captionCollection?.highlightColor }

    func setCaptionAccent(_ accent: CaptionAccent) {
        change { $0.captionCollection?.accent = accent }
    }
}

extension QuickEditViewModel {
    /// Captions drawn with a text look ("+ Captions" in Text style, or an edit from before the
    /// collection): Font changes it for every line (one undo step).
    func updateCaptionLook(_ update: (inout TextLook) -> Void) {
        change { snapshot in
            var look = snapshot.captionLook ?? TypePreset.cue.look(for: .caption)
            update(&look)
            snapshot.captionLook = look
            snapshot.captionPreset = nil
        }
    }
}
