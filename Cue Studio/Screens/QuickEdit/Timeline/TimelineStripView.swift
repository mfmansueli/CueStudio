//
//  TimelineStripView.swift
//  Cue Studio
//

import SwiftUI

/// The Quick edit timeline: the frames of what the handles can reach, with what they trimmed off
/// dimmed outside them, the yellow trim handles, a thin cut line between sections (the frames run
/// edge to edge: a cut is never a gap) with a small mark to pick its transition, the selected
/// section, the red "Remove part" range and the playhead. A bubble above shows the time being set.
///
/// One drag gesture reads every touch and decides what it holds where the finger lands (see
/// `TimelineLayout.target`): on the knob row above the frames, the playhead; on the frames, the red
/// range's edges while it shows, else a handle, then the playhead's line, and anywhere else the
/// playhead jumps to the finger and follows it; a tap also selects the section there, or the cut
/// when it lands on its mark. What a touch took hold of stays the same until it lifts, so the
/// playhead and the handles never move each other. Both handles follow the finger the same way, to
/// the moment of the recording under it, straight through cuts: while a handle is held the strip
/// stays as it was (`QuickEditViewModel.trimOrigin`), so a section the handle takes out doesn't
/// shift the frames under the finger. Nothing plays while a finger is down. Everything a finger
/// sets lands on a frame (`FrameGrid`).
///
/// Zoom (`TimelineZoomController`): while the red range shows, the strip zooms in time so the range
/// stays comfortable to see and to edit, down to frame by frame for a few frames; the edge under the
/// finger stays under it while the zoom glides. A pinch zooms by hand (and turns the automatic zoom
/// off until the next "Remove part"); holding something near a side scrolls the strip (auto-pan).
struct TimelineStripView: View {
    let viewModel: QuickEditViewModel
    let zoom: TimelineZoomController

    static let bubbleHeight: CGFloat = 30
    static let knobHeight: CGFloat = 16
    static let framesHeight: CGFloat = 80
    /// A finger this close to a side of the frames, holding something, scrolls the strip.
    static let autoPanZone: CGFloat = 36
    /// Points per second the strip scrolls with the finger at the very side.
    static let autoPanSpeed: CGFloat = 520
    /// Room kept between the red range and the sides when the zoom changes.
    static let selectionMargin: CGFloat = 24
    /// The mark on a cut that picks its transition.
    static let joinMarkSize: CGFloat = 20
    /// How far above and below a cut's mark a tap still picks it.
    static let joinMarkReach: CGFloat = 18
    /// Sections narrower than this on screen don't show the marks of their cuts (unless selected).
    static let joinMarkRoom: CGFloat = 26

    @State private var drag: Drag?
    /// Where the finger is while it holds something, for auto-pan.
    @State private var finger: CGPoint?
    @State private var width: CGFloat = 0
    @State private var pinch: Pinch?
    @State private var autoPan: Task<Void, Never>?
    /// The playhead when the touch began, so a touch that becomes a pinch leaves it where it was.
    @State private var playheadAtTouch: TimeInterval = 0
    /// The cut whose mark the touch began on: a tap there selects the cut.
    @State private var touchedJoin: Int?
    /// Resets when the system cancels the touch, which `onEnded` never hears about.
    @GestureState private var isTouching = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `grab` is how far from the thing held the finger landed, so it never jumps to the finger.
    /// `from` is where it was, for a touch that becomes a pinch.
    private enum Drag: Equatable {
        case trim(TrimHandle, grab: CGFloat, from: TimeInterval)
        case removal(RemovalEdge, grab: CGFloat, from: TimeInterval)
        /// `grab` keeps the playhead where it sat under the finger instead of jumping to it.
        case scrub(grab: CGFloat)
        /// A second finger made it a pinch: nothing is dragged until the fingers lift.
        case pinched
    }

    /// The zoom and the moment of the strip under the fingers when the pinch began.
    private struct Pinch {
        let zoom: CGFloat
        let time: TimeInterval
        let x: CGFloat
    }

    /// What the zoom's limits depend on.
    private struct ZoomBasis: Equatable {
        let fitPointsPerSecond: CGFloat
        let frameRate: Double
    }

    var body: some View {
        drawing.keepsLeftToRight()
    }

    @ViewBuilder
    private var drawing: some View {
        GeometryReader { proxy in
            let layout = makeLayout(width: proxy.size.width)
            let handles = (start: layout.startHandleX, end: layout.endHandleX)
            ZStack(alignment: .topLeading) {
                TimelineFramesView(
                    videoURL: viewModel.videoURL, layout: layout,
                    frameCount: TimelineLayout.frameCount(width: proxy.size.width, tileWidth: Self.framesHeight * 9 / 16),
                    frameRate: viewModel.frameRate, readsZoomedFrames: true, otherSources: viewModel.clipSourceURLs
                )
                .frame(width: proxy.size.width, height: Self.framesHeight)
                .offset(y: framesTop)
                trimDims(layout, handles: handles)
                cutLines(layout)
                selection(layout)
                trimBracket(layout, handles: handles)
                removalRange(layout)
                TimelinePlayheadView(
                    viewModel: viewModel, layout: layout, zoom: zoom,
                    knobHeight: Self.knobHeight, framesHeight: Self.framesHeight
                )
                .offset(y: Self.bubbleHeight)
                joinMarks(layout)
                bubble(layout, handles: handles)
                handleElement(.start, x: handles.start)
                handleElement(.end, x: handles.end)
                removalEdgeElements(layout)
                joinElements(layout)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            // Zoomed in, the strip runs on past both sides.
            .clipped()
            .contentShape(Rectangle())
            .gesture(dragGesture(layout))
            .simultaneousGesture(pinchGesture(layout))
        }
        .frame(height: Self.bubbleHeight + Self.knobHeight + Self.framesHeight + 4)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: isTouching) { _, touching in
            if !touching { finish() }
        }
        .onChange(of: zoomBasis, initial: true) { _, basis in
            zoom.configure(fitPointsPerSecond: basis.fitPointsPerSecond, frameRate: basis.frameRate)
        }
        .onChange(of: viewModel.removalRange) { old, new in
            followSelection(from: old, to: new)
        }
        .onChange(of: zoom.zoom) {
            regrab()
        }
    }

    private var framesTop: CGFloat { Self.bubbleHeight + Self.knobHeight }

    private func makeLayout(width: CGFloat) -> TimelineLayout {
        TimelineLayout(
            timeline: viewModel.edit.timeline, width: width, reach: viewModel.trimOrigin,
            zoom: zoom.zoom, offset: zoom.offset
        )
    }

    /// The strip as it is now (zoom and scroll included), for work outside `body`.
    private var currentLayout: TimelineLayout { makeLayout(width: width) }

    private var zoomBasis: ZoomBasis {
        ZoomBasis(fitPointsPerSecond: currentLayout.fitPointsPerSecond, frameRate: viewModel.frameRate)
    }

    // MARK: - Layers

    /// `minX`…`maxX` cut to what shows, with a little to spare either side so a border past the
    /// edge stays hidden: zoomed in, a stretch can be thousands of points wide.
    private func onScreen(from minX: CGFloat, to maxX: CGFloat, in layout: TimelineLayout) -> (x: CGFloat, width: CGFloat) {
        let low = max(minX, -24)
        let high = min(maxX, layout.width + 24)
        return (low, max(0, high - low))
    }

    /// What the handles trimmed off, darkened: it stays on the strip so a handle can bring it back.
    @ViewBuilder
    private func trimDims(_ layout: TimelineLayout, handles: (start: CGFloat, end: CGFloat)) -> some View {
        if let first = layout.regions.first, let last = layout.regions.last {
            let head = onScreen(from: first.minX, to: handles.start, in: layout)
            let tail = onScreen(from: handles.end, to: last.maxX, in: layout)
            Rectangle()
                .fill(Palette.trimDim)
                .frame(width: head.width, height: Self.framesHeight)
                .offset(x: head.x, y: framesTop)
                .allowsHitTesting(false)
            Rectangle()
                .fill(Palette.trimDim)
                .frame(width: tail.width, height: Self.framesHeight)
                .offset(x: tail.x, y: framesTop)
                .allowsHitTesting(false)
        }
    }

    /// A thin line where one section cuts to the next: a division, not a gap. Yellow on the
    /// selected cut.
    private func cutLines(_ layout: TimelineLayout) -> some View {
        ForEach(1..<max(1, layout.timeline.segments.count), id: \.self) { index in
            let isSelected = viewModel.selectedJoinIndex == index
            let lineWidth: CGFloat = isSelected ? 2 : 1
            Rectangle()
                .fill(isSelected ? Palette.acc : Palette.cutLine)
                .frame(width: lineWidth, height: Self.framesHeight)
                .offset(x: layout.joinX(index) - lineWidth / 2, y: framesTop)
                .allowsHitTesting(false)
        }
    }

    /// Whether the cut before the section at `index` shows its mark: not while trimming or placing
    /// the red range, and only with room for it on both sides (always when it's selected).
    private func showsJoinMark(_ index: Int, in layout: TimelineLayout) -> Bool {
        guard !isTrimming, viewModel.removalRange == nil, layout.timeline.segments.indices.contains(index), index > 0 else { return false }
        let x = layout.joinX(index)
        guard layout.visibleFrames.contains(x) else { return false }
        if viewModel.selectedJoinIndex == index { return true }
        return min(layout.piece(index - 1).width, layout.piece(index).width) >= Self.joinMarkRoom
    }

    /// On each cut, a small mark with its transition: tap it to pick one. Quiet for a hard cut,
    /// yellow once a transition is set.
    private func joinMarks(_ layout: TimelineLayout) -> some View {
        ForEach(1..<max(1, layout.timeline.segments.count), id: \.self) { index in
            if showsJoinMark(index, in: layout) {
                let transition = layout.timeline.transition(atJoin: index)
                let isSelected = viewModel.selectedJoinIndex == index
                let isSet = transition != .hardCut
                let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
                Image(systemName: transition.systemImage)
                    .font(.caption2.weight(.heavy))
                    .imageScale(.small)
                    .foregroundStyle(isSet ? Palette.accInk : Palette.ink)
                    .frame(width: Self.joinMarkSize, height: Self.joinMarkSize)
                    .background(isSet ? Palette.acc : Palette.joinMark, in: shape)
                    .overlay(shape.strokeBorder(isSelected ? Palette.acc : Palette.bubbleBorder, lineWidth: isSelected ? 1.5 : 0.5))
                    .offset(
                        x: layout.joinX(index) - Self.joinMarkSize / 2,
                        y: framesTop + (Self.framesHeight - Self.joinMarkSize) / 2
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func selection(_ layout: TimelineLayout) -> some View {
        if let index = viewModel.selectedSegmentIndex, layout.timeline.segments.count > 1, !isTrimming {
            let region = layout.piece(index)
            let shown = onScreen(from: region.minX, to: region.maxX, in: layout)
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            shape
                .fill(Palette.selectedSectionFill)
                .overlay(shape.strokeBorder(Palette.ink, lineWidth: 2))
                .frame(width: max(4, shown.width), height: Self.framesHeight)
                .offset(x: shown.x, y: framesTop)
                .allowsHitTesting(false)
        }
    }

    /// The yellow frame around what plays, with a handle at each end.
    private func trimBracket(_ layout: TimelineLayout, handles: (start: CGFloat, end: CGFloat)) -> some View {
        let height = Self.framesHeight + 6
        let bars = onScreen(from: handles.start, to: handles.end, in: layout)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Rectangle().fill(Palette.acc).frame(height: 3)
                Spacer(minLength: 0)
                Rectangle().fill(Palette.acc).frame(height: 3)
            }
            .frame(width: bars.width, height: height)
            .offset(x: bars.x)
            TrimHandleView(edge: .start, isActive: viewModel.activeHandle == .start)
                .frame(height: height)
                .offset(x: handles.start - TimelineLayout.handleWidth)
            TrimHandleView(edge: .end, isActive: viewModel.activeHandle == .end)
                .frame(height: height)
                .offset(x: handles.end)
        }
        .offset(y: framesTop - 3)
        .allowsHitTesting(false)
    }

    /// "Remove part": the red range and its two edges.
    @ViewBuilder
    private func removalRange(_ layout: TimelineLayout) -> some View {
        if let range = viewModel.removalRange {
            let start = layout.x(forEdited: range.lowerBound)
            let end = layout.x(forEdited: range.upperBound)
            let shown = onScreen(from: start, to: end, in: layout)
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            shape
                .fill(Palette.removalFill)
                .overlay(shape.strokeBorder(Palette.danger, lineWidth: 2))
                .frame(width: max(4, shown.width), height: Self.framesHeight + 6)
                .offset(x: shown.x, y: framesTop - 3)
                .allowsHitTesting(false)
            ForEach([start, end], id: \.self) { x in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Palette.danger)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
                    .frame(width: 12, height: Self.framesHeight - 24)
                    .offset(x: x - 6, y: framesTop + 12)
                    .allowsHitTesting(false)
            }
        }
    }

    /// The time being set: a handle's place in the recording ("Start 00:02.14"), an edge of the
    /// red range, or the playhead while scrubbing.
    @ViewBuilder
    private func bubble(_ layout: TimelineLayout, handles: (start: CGFloat, end: CGFloat)) -> some View {
        if let content = bubbleContent(layout, handles: handles) {
            Text(content.text)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(Palette.acc)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Palette.bg, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.bubbleBorder, lineWidth: 0.5))
                .fixedSize()
                .frame(width: 0)
                .offset(x: min(max(content.x, 44), layout.width - 44))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Zoomed in, the times read to the hundredth even on a long take.
    private func bubbleContent(_ layout: TimelineLayout, handles: (start: CGFloat, end: CGFloat)) -> (text: String, x: CGFloat)? {
        let timeline = viewModel.edit.timeline
        let precise = zoom.isZoomed
        switch drag {
        case let .trim(handle, _, _):
            let total = timeline.sourceDuration
            return handle == .start
                ? (String(localized: "Start \(DurationText.timecode(timeline.trimStart, total: total, precise: precise))"), handles.start)
                : (String(localized: "End \(DurationText.timecode(timeline.trimEnd, total: total, precise: precise))"), handles.end)
        case let .removal(edge, _, _):
            guard let range = viewModel.removalRange else { return nil }
            let time = edge == .start ? range.lowerBound : range.upperBound
            return (DurationText.timecode(time, total: timeline.editedDuration, precise: precise), layout.x(forEdited: time))
        case .scrub:
            let time = viewModel.player.currentTime
            return (DurationText.timecode(time, total: timeline.editedDuration, precise: precise), layout.x(forEdited: time))
        case .pinched, nil:
            return nil
        }
    }

    /// VoiceOver moves a handle or an edge by half a second, or by one frame when zoomed in that far.
    private var accessibilityStep: TimeInterval {
        zoom.isFramePrecise ? viewModel.frameGrid.frameDuration : 0.5
    }

    /// Where a handle can be caught, for VoiceOver (adjustable) and UI tests. Touches go to the
    /// strip's gesture.
    private func handleElement(_ handle: TrimHandle, x handleX: CGFloat) -> some View {
        let outer = TimelineLayout.handleWidth + TimelineLayout.handleOuterReach
        let reach = outer + TimelineLayout.handleReach
        let x = handle == .start ? handleX - outer : handleX - TimelineLayout.handleReach
        let step = accessibilityStep
        return Color.clear
            .frame(width: reach, height: Self.framesHeight)
            .offset(x: x, y: framesTop)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(handle == .start ? Text("Start of the edit") : Text("End of the edit"))
            .accessibilityValue(Text(viewModel.handleAccessibilityValue(handle)))
            .accessibilityAdjustableAction { direction in
                viewModel.nudgeTrim(handle, by: direction == .increment ? step : -step)
            }
            .accessibilityIdentifier(handle == .start ? "edit.trimStartHandle" : "edit.trimEndHandle")
    }

    /// The red range's edges, for VoiceOver (adjustable) and UI tests.
    @ViewBuilder
    private func removalEdgeElements(_ layout: TimelineLayout) -> some View {
        if let range = viewModel.removalRange {
            let step = accessibilityStep
            ForEach([RemovalEdge.start, .end], id: \.self) { edge in
                let time = edge == .start ? range.lowerBound : range.upperBound
                Color.clear
                    .frame(width: TimelineLayout.removalEdgeReach * 2, height: Self.framesHeight)
                    .offset(x: layout.x(forEdited: time) - TimelineLayout.removalEdgeReach, y: framesTop)
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel(edge == .start ? Text("Start of the part to remove") : Text("End of the part to remove"))
                    .accessibilityValue(Text(DurationText.timecode(time, total: viewModel.edit.editedDuration, precise: zoom.isZoomed)))
                    .accessibilityAdjustableAction { direction in
                        viewModel.moveRemovalEdge(edge, toEdited: time + (direction == .increment ? step : -step))
                        viewModel.endScrub()
                    }
                    .accessibilityIdentifier(edge == .start ? "edit.removalStartEdge" : "edit.removalEndEdge")
            }
        }
    }

    /// The cuts' marks, for VoiceOver and UI tests: a button that selects the cut, to pick its
    /// transition. Touches go to the strip's gesture.
    private func joinElements(_ layout: TimelineLayout) -> some View {
        ForEach(1..<max(1, layout.timeline.segments.count), id: \.self) { index in
            if showsJoinMark(index, in: layout) {
                let transition = layout.timeline.transition(atJoin: index)
                Color.clear
                    .frame(width: TimelineLayout.joinReach * 2, height: Self.joinMarkReach * 2)
                    .offset(
                        x: layout.joinX(index) - TimelineLayout.joinReach,
                        y: framesTop + Self.framesHeight / 2 - Self.joinMarkReach
                    )
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel(Text("Transition at cut \(index)"))
                    .accessibilityValue(Text(transition.label))
                    .accessibilityAddTraits(viewModel.selectedJoinIndex == index ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction { viewModel.tapJoin(index) }
                    .accessibilityIdentifier("edit.join.\(index)")
            }
        }
    }

    // MARK: - Touch

    private func dragGesture(_ layout: TimelineLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isTouching) { _, touching, _ in touching = true }
            .onChanged { value in
                if drag == nil { drag = pinch == nil ? begin(at: value.startLocation, layout: layout) : Drag.pinched }
                guard drag != .pinched else { return }
                finger = value.location
                // Zoom and scroll as they are now: they can change while the finger is down.
                apply(drag, atX: value.location.x, layout: makeLayout(width: layout.width))
                if abs(value.translation.width) > 6 { startAutoPanIfNeeded() }
            }
            .onEnded { value in
                let isTap = abs(value.translation.width) < 6 && abs(value.translation.height) < 6
                if isTap, case .scrub = drag {
                    if let join = touchedJoin {
                        viewModel.tapJoin(join)
                    } else {
                        viewModel.tapTimeline(onPiece: makeLayout(width: layout.width).segmentIndex(atX: value.location.x))
                    }
                }
                finish()
            }
    }

    private func begin(at location: CGPoint, layout: TimelineLayout) -> Drag {
        let x = location.x
        let playhead = viewModel.player.currentTime
        playheadAtTouch = playhead
        let playheadX = layout.x(forEdited: playhead)
        let target = layout.target(
            atX: x, playheadX: playheadX, aboveFrames: location.y < framesTop - 3, removal: viewModel.removalRange
        )
        touchedJoin = nil
        if target == .playhead || target == .timeline,
           abs(location.y - (framesTop + Self.framesHeight / 2)) <= Self.joinMarkReach,
           let join = layout.join(atX: x), showsJoinMark(join, in: layout) {
            touchedJoin = join
        }
        switch target {
        case .handle(let handle):
            let timeline = viewModel.edit.timeline
            viewModel.beginTrim(handle)
            return handle == .start
                ? .trim(.start, grab: x - layout.startHandleX, from: timeline.trimStart)
                : .trim(.end, grab: x - layout.endHandleX, from: timeline.trimEnd)
        case .removalEdge(let edge):
            let time = (edge == .start ? viewModel.removalRange?.lowerBound : viewModel.removalRange?.upperBound) ?? 0
            return .removal(edge, grab: x - layout.x(forEdited: time), from: time)
        case .playhead:
            return .scrub(grab: x - playheadX)
        case .timeline:
            return .scrub(grab: 0)
        }
    }

    /// Moves what the finger holds to the moment under it, on a frame.
    private func apply(_ drag: Drag?, atX x: CGFloat, layout: TimelineLayout) {
        switch drag {
        case let .trim(handle, grab, _):
            let recording = TimeSpan(start: 0, end: viewModel.edit.timeline.sourceDuration)
            viewModel.trim(handle, toSource: viewModel.frameGrid.snapped(layout.sourceTime(atX: x - grab), in: recording))
        case let .removal(edge, grab, _):
            viewModel.moveRemovalEdge(edge, toEdited: viewModel.frameSnapped(edited: layout.editedTime(atX: x - grab)))
        case let .scrub(grab):
            viewModel.scrub(to: viewModel.frameSnapped(edited: layout.editedTime(atX: x - grab)))
        case .pinched, nil:
            break
        }
    }

    /// After the zoom changed under a finger, what it holds stays at its moment: the finger now
    /// holds it from where it is.
    private func regrab() {
        guard let finger, width > 0 else { return }
        let layout = currentLayout
        switch drag {
        case let .trim(handle, _, from):
            let x = handle == .start ? layout.startHandleX : layout.endHandleX
            drag = .trim(handle, grab: finger.x - x, from: from)
        case let .removal(edge, _, from):
            guard let range = viewModel.removalRange else { return }
            let x = layout.x(forEdited: edge == .start ? range.lowerBound : range.upperBound)
            drag = .removal(edge, grab: finger.x - x, from: from)
        case .scrub:
            drag = .scrub(grab: finger.x - layout.x(forEdited: viewModel.player.currentTime))
        case .pinched, nil:
            break
        }
    }

    private var isTrimming: Bool {
        if case .trim = drag { return true }
        return false
    }

    private func finish() {
        stopAutoPan()
        switch drag {
        case .trim: viewModel.endTrim()
        case .scrub, .removal: viewModel.endScrub()
        case .pinched, nil: break
        }
        drag = nil
        finger = nil
        touchedJoin = nil
    }

    // MARK: - Pinch

    /// Pinch out to zoom in around the fingers, pinch in to zoom out. A touch that becomes a pinch
    /// puts back whatever its first finger moved.
    private func pinchGesture(_ layout: TimelineLayout) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.02)
            .onChanged { value in
                let current = makeLayout(width: layout.width)
                let start: Pinch
                if let pinch {
                    start = pinch
                } else {
                    cancelDragForPinch()
                    zoom.beginPinch()
                    start = Pinch(zoom: zoom.zoom, time: current.stripTime(atX: value.startLocation.x), x: value.startLocation.x)
                    pinch = start
                }
                let target = min(max(1, start.zoom * value.magnification), zoom.maximum)
                zoom.set(zoom: target, offset: current.scrollOffset(placing: start.time, atX: start.x, zoom: target))
            }
            .onEnded { _ in
                pinch = nil
                if zoom.zoom < 1.05 { zoom.set(zoom: 1, offset: 0) }
                if drag == .pinched, !isTouching { drag = nil }
            }
    }

    private func cancelDragForPinch() {
        stopAutoPan()
        guard let held = drag else { return }
        switch held {
        case let .trim(handle, _, from):
            viewModel.trim(handle, toSource: from)
            viewModel.endTrim()
        case let .removal(edge, _, from):
            viewModel.moveRemovalEdge(edge, toEdited: from)
        case .scrub, .pinched:
            break
        }
        if held != .pinched {
            viewModel.scrub(to: playheadAtTouch)
            viewModel.endScrub()
        }
        drag = .pinched
        finger = nil
    }

    // MARK: - Zoom

    /// The red range came, changed or went: zoom so it stays comfortable to edit (see
    /// `TimelineZoom.level`), or back to the whole take when it's gone.
    private func followSelection(from old: ClosedRange<TimeInterval>?, to new: ClosedRange<TimeInterval>?) {
        guard width > 0 else { return }
        let layout = currentLayout
        guard let range = new else {
            // "Remove part" is over: back to the whole take, unless the creator zoomed by hand.
            guard !zoom.isManual, zoom.targetZoom > 1 else { return }
            let time = viewModel.player.currentTime
            zoom.glide(
                to: 1, keeping: layout.stripTime(forEdited: time), fromX: layout.x(forEdited: time),
                toX: layout.zoomed(1, offset: 0).x(forEdited: time), in: layout, animated: !reduceMotion
            )
            return
        }
        if old == nil { zoom.resumeAutomatic() }
        let target = zoom.isManual ? zoom.targetZoom : TimelineZoom.level(
            forSelection: range.upperBound - range.lowerBound, current: zoom.targetZoom,
            fitPointsPerSecond: layout.fitPointsPerSecond, room: layout.room, maximum: zoom.maximum
        )
        if abs(target - zoom.targetZoom) > 0.001 {
            let anchor = zoomAnchor(for: range, zoom: target, layout: layout)
            zoom.glide(to: target, keeping: anchor.time, fromX: anchor.from, toX: anchor.to, in: layout, animated: !reduceMotion)
        } else if drag == nil {
            reveal(range, layout: layout)
        }
    }

    /// The moment the zoom keeps in place and where it ends up. Dragging an edge, that edge stays
    /// under the finger, unless the rest of the range would fall off a side; otherwise the range's
    /// middle comes to the middle.
    private func zoomAnchor(
        for range: ClosedRange<TimeInterval>, zoom target: CGFloat, layout: TimelineLayout
    ) -> (time: TimeInterval, from: CGFloat, to: CGFloat) {
        let frames = layout.visibleFrames
        let low = frames.lowerBound + Self.selectionMargin
        let high = frames.upperBound - Self.selectionMargin
        if case let .removal(edge, _, _) = drag {
            let time = edge == .start ? range.lowerBound : range.upperBound
            let x = layout.x(forEdited: time)
            let span = CGFloat(range.upperBound - range.lowerBound) * layout.fitPointsPerSecond * target
            let to: CGFloat
            if high - low > span {
                to = edge == .start ? min(max(x, low), high - span) : min(max(x, low + span), high)
            } else {
                to = edge == .start ? low : high
            }
            return (layout.stripTime(forEdited: time), x, to)
        }
        let middle = (range.lowerBound + range.upperBound) / 2
        return (layout.stripTime(forEdited: middle), layout.x(forEdited: middle), (frames.lowerBound + frames.upperBound) / 2)
    }

    /// Scrolls the red range back into view when part of it is off a side.
    private func reveal(_ range: ClosedRange<TimeInterval>, layout: TimelineLayout) {
        let frames = layout.visibleFrames
        guard layout.x(forEdited: range.lowerBound) < frames.lowerBound
            || layout.x(forEdited: range.upperBound) > frames.upperBound else { return }
        let middle = (range.lowerBound + range.upperBound) / 2
        zoom.glide(
            to: zoom.targetZoom, keeping: layout.stripTime(forEdited: middle), fromX: layout.x(forEdited: middle),
            toX: (frames.lowerBound + frames.upperBound) / 2, in: layout, animated: !reduceMotion
        )
    }

    // MARK: - Auto-pan

    /// Zoomed in, a finger held near a side scrolls the strip, faster the closer it gets, and what
    /// it holds keeps following it onto the time that scrolls in.
    private func startAutoPanIfNeeded() {
        guard autoPan == nil, let finger, width > 0, autoPanVelocity(atX: finger.x, layout: currentLayout) != 0 else { return }
        autoPan = Task {
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                let now = clock.now
                let seconds = min(0.05, (now - last) / .seconds(1))
                last = now
                guard !Task.isCancelled, autoPanStep(seconds: seconds) else { break }
            }
            if !Task.isCancelled { autoPan = nil }
        }
    }

    private func autoPanStep(seconds: Double) -> Bool {
        guard let finger, width > 0, drag != nil, drag != .pinched else { return false }
        let layout = currentLayout
        let velocity = autoPanVelocity(atX: finger.x, layout: layout)
        guard velocity != 0 else { return false }
        zoom.pan(to: layout.clampedOffset(layout.offset + velocity * CGFloat(seconds)))
        apply(drag, atX: finger.x, layout: currentLayout)
        return true
    }

    /// Points per second to scroll with the finger at `x`: 0 away from the sides, or when the strip
    /// can't scroll further that way.
    private func autoPanVelocity(atX x: CGFloat, layout: TimelineLayout) -> CGFloat {
        guard layout.maxOffset > 0 else { return 0 }
        let frames = layout.visibleFrames
        let intoStart = frames.lowerBound + Self.autoPanZone - x
        if intoStart > 0, layout.offset > 0 {
            let depth = min(1, intoStart / Self.autoPanZone)
            return -Self.autoPanSpeed * depth * depth
        }
        let intoEnd = x - (frames.upperBound - Self.autoPanZone)
        if intoEnd > 0, layout.offset < layout.maxOffset {
            let depth = min(1, intoEnd / Self.autoPanZone)
            return Self.autoPanSpeed * depth * depth
        }
        return 0
    }

    private func stopAutoPan() {
        autoPan?.cancel()
        autoPan = nil
    }
}
