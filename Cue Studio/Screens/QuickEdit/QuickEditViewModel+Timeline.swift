//
//  QuickEditViewModel+Timeline.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The timeline with the playhead fixed in the middle: what it shows (`timelineInput`), and what
/// it does with a scrub, a tap, a pinch and a handle. The player stays the clock: the timeline
/// follows it while it plays and scrubs it while a finger moves the content.
extension QuickEditViewModel {
    // MARK: - What it shows

    /// Everything the timeline draws, for `heightClass`. Reads the playhead only while a
    /// voice-over records (its track grows with it).
    func timelineInput(heightClass: EditorHeightClass) -> TimelineGeometry.Input {
        let timeline = edit.timeline
        var input = TimelineGeometry.Input(duration: edit.editedDuration)
        var start: TimeInterval = 0
        input.clips = timeline.segments.map { segment in
            defer { start += segment.duration }
            return TimelineGeometry.ClipInput(
                id: segment.id, start: start, duration: segment.duration,
                sourceStart: segment.sourceStart, sourceEnd: segment.sourceEnd, speed: segment.speed,
                sourceID: segment.sourceID, badge: Self.badge(of: segment), transition: segment.transitionIn
            )
        }
        input.texts = edit.editedTexts(in: timeline).map { text, span in
            TimelineGeometry.ItemInput(
                id: text.id, span: span, label: text.isEmpty ? text.role.label : text.displayText,
                keyframes: text.keyframes.map { span.start + $0.time }.filter { $0 <= span.end + 0.001 }
            )
        }
        input.media = edit.editedMedia(in: timeline).map { item, span in
            TimelineGeometry.ItemInput(
                id: item.id, span: span, label: item.kind == .photo ? String(localized: "Photo") : String(localized: "Video")
            )
        }
        input.captions = edit.editedCaptionInstances.map { line, cueID in
            TimelineGeometry.ItemInput(id: cueID, span: line.span, label: line.text)
        }
        input.showsCaptions = edit.showsCaptions
        input.music = edit.music.compactMap { clip in
            clip.span(inEditOf: edit.editedDuration).map { TimelineGeometry.ItemInput(id: clip.id, span: $0, label: clip.title) }
        }
        input.voiceOvers = edit.voiceOvers.compactMap { clip in
            clip.editedSpan(in: timeline).map { TimelineGeometry.ItemInput(id: clip.id, span: $0, label: String(localized: "Voice-over")) }
        }
        if let recordingStart {
            input.recording = TimeSpan(start: recordingStart, end: max(recordingStart, player.currentTime))
        }
        if panel == .pauses { input.pauses = timelinePauses }
        input.selection = selection
        input.selectedJoin = selectedJoinID
        input.panelIsOpen = panel != nil
        input.focusedLane = panel?.focusedLane
        input.heightClass = heightClass
        input.pointsPerSecond = TimelineGeometry.basePointsPerSecond * timelineZoom
        return input
    }

    /// "1.5×", "Push in", "Muted", joined: the yellow badge on a clip.
    static func badge(of segment: EditSegment) -> String? {
        var parts: [String] = []
        if abs(segment.speed - 1) > 0.001 {
            parts.append(segment.speed.formatted(.number.precision(.fractionLength(0...2)).locale(.interface)) + "×")
        }
        if let zoom = segment.zoom { parts.append(zoom.label) }
        if segment.isMuted { parts.append(String(localized: "Muted")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The pauses on the video track while Pauses is open, marked to go or kept.
    var timelinePauses: [TimelineGeometry.PauseInput] {
        pauseCandidates.compactMap { pause in
            guard let span = edit.timeline.editedSpan(forSource: pause.span) else { return nil }
            return TimelineGeometry.PauseInput(id: pause.id, span: span, isMarked: isMarked(pause))
        }
    }

    // MARK: - Zoom

    /// Zoom by pinch, kept between panels; the time under the playhead stays put.
    func setTimelineZoom(_ zoom: CGFloat) {
        timelineZoom = min(max(zoom, TimelineGeometry.zoomRange.lowerBound), TimelineGeometry.zoomRange.upperBound)
    }

    // MARK: - Tapping

    /// A tap on the timeline (a move under `TimelineGeometry.tapSlop`): picks what it lands on, or
    /// lets go on empty space. While Pauses is open only the pauses answer.
    func tapTimeline(_ hit: TimelineGeometry.Hit?) {
        guard isReady, !recorder.isRecording else { return }
        if panel == .pauses {
            if case .pause(let id) = hit { togglePauseMark(id) }
            return
        }
        guard let hit else {
            selection = nil
            return
        }
        switch hit {
        case .cover:
            selection = nil
            toolMenu = nil
            panel = .cover
        case .addClip:
            mediaInsertMode = .clip
            sheet = .media
        case .addText:
            selection = nil
            panel = nil
            toolMenu = .text
        case .captions: openCaptions()
        case .addAudio:
            selection = nil
            panel = nil
            toolMenu = .audio
        case .pause(let id): togglePauseMark(id)
        case .join(let id): pickJoin(id)
        case .clip(let id): pick(.clip(id))
        case .item(let kind, let id): Self.selection(of: kind, id).map(pick)
        }
    }

    /// What picking a track item selects (nothing for the voice-over being recorded).
    static func selection(of kind: TimelineGeometry.ItemKind, _ id: UUID) -> EditorSelection? {
        switch kind {
        case .text: .text(id)
        case .media: .media(id)
        case .caption: .caption(id)
        case .music: .music(id)
        case .voiceOver: .voiceOver(id)
        case .recording: nil
        }
    }

    /// A cut's mark: picks the cut and opens its transitions (tapped again, lets go).
    func pickJoin(_ id: UUID) {
        guard selectedJoinID != id else {
            panel = nil
            return
        }
        Haptics.selection()
        selection = nil
        toolMenu = nil
        if panel != .transition { panel = nil }
        selectedJoinID = id
        panel = .transition
    }

    /// VoiceOver: the transitions of the cut nearest to the playhead.
    func pickNearestJoin() {
        let time = player.currentTime
        guard let nearest = cuts.min(by: { abs($0.time - time) < abs($1.time - time) }) else {
            toast.show(String(localized: "No cuts yet"))
            return
        }
        player.pause()
        player.seek(to: nearest.time)
        pickJoin(edit.timeline.segments[nearest.index].id)
    }

    /// Picks an item; a panel that can't work on it closes, one that can stays.
    private func pick(_ item: EditorSelection) {
        Haptics.selection()
        if let panel {
            let keeps = switch panel {
            case .captions: item.captionID != nil
            case .textStyle: item.textID != nil
            case .speed, .zoom, .volume, .voice: item.clipID != nil
            default: false
            }
            if !keeps { self.panel = nil }
        }
        selection = item
    }

    /// Marks a pause to go, or to stay.
    func togglePauseMark(_ id: UUID) {
        toggleMark(id)
    }

    // MARK: - Scrubbing

    /// The content moved under the playhead: the player follows, paused.
    func scrubTimeline(to time: TimeInterval) {
        guard isReady, !recorder.isRecording else { return }
        player.scrub(to: min(max(0, time), edit.editedDuration))
    }

    func endTimelineScrub() {
        player.endScrub()
    }

    // MARK: - Handles

    /// A handle is held: the drag is one undo step, the player shows the edge.
    func beginTimelineHandle(_ target: TimelineGeometry.HandleTarget, snapTimes: [TimeInterval]) {
        guard isReady, handleDrag == nil else { return }
        player.pause()
        beginChange()
        let playhead = player.currentTime
        switch target {
        case .clip(let id, let edge):
            guard let index = edit.timeline.index(ofSegment: id) else { return }
            let segment = edit.timeline.segments[index]
            let start = edit.timeline.editedStart(ofSegmentAt: index)
            handleDrag = TimelineHandleDrag(
                target: target, playhead: playhead, edgeTime: edge == .start ? start : start + segment.duration,
                clipSpan: segment.span, clipSpeed: segment.speed, bar: nil, snapTimes: snapTimes
            )
        case .item(let kind, let id, let edge):
            guard let bar = layerBar(kind, id) else { return }
            let own = [bar.span.start, bar.span.end]
            handleDrag = TimelineHandleDrag(
                target: target, playhead: playhead, edgeTime: edge == .start ? bar.span.start : bar.span.end,
                clipSpan: nil, clipSpeed: 1, bar: bar,
                snapTimes: snapTimes.filter { time in !own.contains { abs($0 - time) < 0.000_1 } }
            )
        }
    }

    /// Moves the held edge by `offset` edited seconds (the finger's travel over the zoom). Returns
    /// the bubble's text and, for a clip's left handle, how far the content must stay shifted so
    /// the clip's frames don't move under the finger.
    @discardableResult
    func moveTimelineHandle(by offset: TimeInterval) -> (label: String, compensation: TimeInterval) {
        guard let drag = handleDrag else { return ("", 0) }
        let pps = TimelineGeometry.basePointsPerSecond * timelineZoom
        var edge = drag.edgeTime + offset
        if let snap = TimelineSnapping.snapped(edge, to: drag.snapTimes, pointsPerSecond: pps) {
            if abs(snap - (lastHandleSnap ?? -1)) > 0.000_1 { Haptics.snap() }
            lastHandleSnap = snap
            edge = snap
        } else {
            lastHandleSnap = nil
        }
        switch drag.target {
        case .clip(let id, let side):
            guard let span = drag.clipSpan else { return ("", 0) }
            // Every move starts from the clip as it was: the drag is absolute.
            let sourceTime = side == .start
                ? span.start + (edge - drag.edgeTime) * drag.clipSpeed
                : span.end + (edge - drag.edgeTime) * drag.clipSpeed
            var timeline = edit.timeline
            if let index = timeline.index(ofSegment: id) {
                var restored = timeline.segments[index]
                restored.sourceStart = span.start
                restored.sourceEnd = span.end
                timeline.replaceSegment(restored)
            }
            timeline.trimSegment(id: id, edge: side, toSource: sourceTime)
            if timeline != edit.timeline { commit(timeline) }
            guard let index = edit.timeline.index(ofSegment: id) else { return ("", 0) }
            let segment = edit.timeline.segments[index]
            let start = edit.timeline.editedStart(ofSegmentAt: index)
            player.scrub(to: side == .start ? start : max(start, start + segment.duration - 0.03))
            let compensation = side == .start ? -(segment.sourceStart - span.start) / drag.clipSpeed : 0
            return (DurationText.tenths(segment.duration), compensation)
        case .item(_, _, let side):
            guard let bar = drag.bar else { return ("", 0) }
            resizeBar(bar, edge: side == .start ? .start : .end, to: edge)
            guard let now = layerBarForDrag(bar) else { return ("", 0) }
            let edgeNow = side == .start ? now.span.start : now.span.end
            player.scrub(to: min(edgeNow, max(0, edit.editedDuration - 0.03)))
            return (DurationText.editor(edgeNow) + " · " + DurationText.tenths(now.span.duration), 0)
        }
    }

    /// The finger lifted: one undo step, and the playhead goes back where it was.
    func endTimelineHandle() {
        guard let drag = handleDrag else { return }
        handleDrag = nil
        lastHandleSnap = nil
        endChange()
        player.endScrub()
        player.seek(to: min(drag.playhead, edit.editedDuration))
    }

    // MARK: - Private

    private func layerBar(_ kind: TimelineGeometry.ItemKind, _ id: UUID) -> LayerBar? {
        switch kind {
        case .text: textBars.first { $0.id == id }
        case .media: mediaBars.first { $0.id == id }
        case .caption: captionBars.first { captionCueID(forLine: $0.id) == id }
        case .music, .voiceOver, .recording: nil
        }
    }

    /// The bar of the item being dragged, as it is now.
    private func layerBarForDrag(_ bar: LayerBar) -> LayerBar? {
        switch bar.kind {
        case .text: textBars.first { $0.id == bar.id }
        case .media: mediaBars.first { $0.id == bar.id }
        case .caption:
            captionBars.first { captionCueID(forLine: $0.id) == captionCueID(forLine: bar.id) }
        default: nil
        }
    }
}
