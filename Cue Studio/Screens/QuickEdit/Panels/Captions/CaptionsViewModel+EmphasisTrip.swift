//
//  CaptionsViewModel+EmphasisTrip.swift
//  Cue Studio
//

import Foundation

/// Caption style › Custom › Choose words to emphasize (owner, canvas 2 F1): the marked words' color and size are styled there,
/// but the words are picked on their line. The button opens Captions on the line under the playhead, picked and with its words
/// at hand (More › Emphasis), and ✓ or ‹ Style come back to Caption style as it was left: the same tab, scrolled where it was,
/// the playhead where it was and the same thing picked. Leaving Captions any other way (another tool, the track) just leaves.
extension CaptionsViewModel {
    /// The line the button opens: the one under the playhead, else the next one, else the last before it. Nil without lines.
    var emphasisTripLine: (cueID: UUID, start: TimeInterval)? {
        let time = player.currentTime
        if let here = lineUnderPlayhead { return (here.cueID, here.line.start) }
        let lines = captionListLines
        guard let line = lines.first(where: { $0.line.start > time }) ?? lines.last else { return nil }
        return (line.cueID, line.line.start)
    }

    /// Choose words to emphasize can open a line: the captions are drawn by the collection and there is a line.
    var canChooseWordsToEmphasize: Bool {
        canMarkCaptionEmphasis && !edit.captions.isEmpty
    }

    /// From Caption style (its tab `tab`, scrolled to `offset`): Captions opens on the line under the playhead (the playhead
    /// goes to a line only when none is under it), picked, with its words to emphasize open.
    func chooseWordsToEmphasize(from tab: EditorPanelTab, offset: CGFloat) {
        guard isReady, canChooseWordsToEmphasize, let target = emphasisTripLine else { return }
        let back = CaptionStyleReturn(tab: tab, offset: offset, time: player.currentTime, selection: selection)
        session.endPreview()
        player.pause()
        if lineUnderPlayhead?.cueID != target.cueID { player.seek(to: target.start + 0.01) }
        expandedLineID = target.cueID
        panel = .captions
        selection = .caption(target.cueID)
        styleReturn = back
    }

    /// The line under the playhead, counting a playhead a frame short of a line's start (where a seek to the line can land) as on it.
    private var lineUnderPlayhead: (line: CaptionCue, cueID: UUID)? {
        let time = player.currentTime
        return captionMap.instance(at: time) ?? captionMap.instance(at: time + 0.05)
    }

    /// ✓ or ‹ Style in Captions after Choose words to emphasize: Caption style again, on the tab and at the scroll it was left
    /// at, the playhead back where it was and what was picked picked again. False when Captions wasn't opened that way.
    @discardableResult
    func returnToCaptionStyle() -> Bool {
        guard let back = styleReturn else { return false }
        session.endPreview()
        player.pause()
        selection = back.selection
        panel = .captionStyle
        panelTab = back.tab
        captionCustomOffset = back.offset
        restoresCustomOffset = back.tab == .adjust
        if abs(player.currentTime - back.time) > 0.001 { player.seek(to: back.time) }
        return true
    }
}
